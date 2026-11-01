// Die drei Edge Functions, ohne Supabase: ein nachgebauter Client, dieselben Regeln wie der Server.
// Läuft mit: deno test --allow-read --allow-net --allow-env functions_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { handle as submit } from "./submit-action/handle.ts";
import { handle as finishBot } from "./finish-bot-match/handle.ts";
import { handle as deleteAccount } from "./delete-account/handle.ts";

const WHITE = "11111111-1111-1111-1111-111111111111";
const BLACK = "22222222-2222-2222-2222-222222222222";
const STRANGER = "33333333-3333-3333-3333-333333333333";
const RULES = JSON.parse(await Deno.readTextFile(new URL("../../../RookRaid/Engine/rookraid-rules.json", import.meta.url)));
const DECK = ["shield", "freeze", "sprint", "lightning"];

interface Calls { rpc: { name: string; args: Record<string, unknown> }[]; deleted: string[]; inserted: unknown[] }

function match(over: Record<string, unknown> = {}) {
  return {
    id: "match-1", status: "active", result: null, is_bot: false,
    white: WHITE, black: BLACK, action_count: 0, rules_version: RULES.version,
    setup: { decks: { white: DECK, black: DECK }, ultimates: { white: "meteor", black: "fortress" } },
    ...over,
  };
}

function admin(row: Record<string, unknown>, actions: { code: string }[] = []): { client: SupabaseClient; calls: Calls } {
  const calls: Calls = { rpc: [], deleted: [], inserted: [] };
  const client = {
    auth: {
      getUser: async (token: string) => token === "good"
        ? { data: { user: { id: WHITE } }, error: null }
        : { data: { user: null }, error: { message: "bad" } },
      admin: { deleteUser: async (id: string) => { calls.deleted.push(id); return { error: null }; } },
    },
    from(table: string) {
      if (table === "matches") {
        return { select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: row, error: null }) }) }) };
      }
      if (table === "match_actions") {
        return {
          select: () => ({ eq: () => ({ order: async () => ({ data: actions, error: null }) }) }),
          insert: async (rows: unknown) => { calls.inserted.push(rows); return { error: null }; },
        };
      }
      if (table === "rules_config") {
        return { select: () => ({ eq: () => ({ single: async () => ({ data: { config: RULES }, error: null }) }) }) };
      }
      throw new Error("unexpected table " + table);
    },
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.rpc.push({ name, args });
      return { data: { ok: true, ply: 1 }, error: null };
    },
  };
  return { client: client as unknown as SupabaseClient, calls };
}

function post(path: string, body: unknown, token?: string) {
  return new Request("http://localhost" + path, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: "Bearer " + token } : {}) },
    body: JSON.stringify(body),
  });
}

async function bodyOf(res: Response): Promise<Record<string, unknown>> {
  return await res.json();
}

Deno.test("submit-action weist Gäste, Fremde, Bots und illegale Züge ab", async () => {
  const open = admin(match());
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }), open.client))).error, "not_authenticated");

  const bad = admin(match());
  assertEquals((await bodyOf(await submit(post("/s", { match_id: 1 }, "good"), bad.client))).error, "bad_request");

  const stranger = admin(match({ white: STRANGER, black: BLACK }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), stranger.client))).error, "not_participant");

  const bot = admin(match({ is_bot: true }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), bot.client))).error, "bot_match_is_local");

  const stale = admin(match({ action_count: 2 }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), stale.client))).error, "out_of_sync");

  const illegal = admin(match());
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "e2e5" }, "good"), illegal.client))).error, "illegal_action");
  assertEquals(illegal.calls.rpc.length, 0);

  const black = admin(match({ white: BLACK, black: WHITE }));
  assertEquals((await bodyOf(await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), black.client))).error, "not_your_turn");
});

Deno.test("submit-action speichert nur einen erlaubten Zug des Spielers am Zug", async () => {
  const legal = admin(match());
  const res = await submit(post("/s", { match_id: "match-1", ply: 0, code: "f2f3" }, "good"), legal.client);
  assertEquals(res.status, 200);
  assertEquals(legal.calls.rpc.length, 1);
  assertEquals(legal.calls.rpc[0].name, "record_action");
  assertEquals(legal.calls.rpc[0].args.p_actor, WHITE);
  assertEquals(legal.calls.rpc[0].args.p_code, "f2f3");
  assertEquals(legal.calls.rpc[0].args.p_result, null);
});

Deno.test("finish-bot-match wertet nur die nachgespielte Partie, und ein Timeout verliert der Mensch", async () => {
  const guest = admin(match({ is_bot: true, black: null }));
  assertEquals((await bodyOf(await finishBot(post("/f", { match_id: "match-1", actions: [], outcome: "resigned" }), guest.client))).error, "not_authenticated");

  const human = admin(match({ is_bot: false }));
  assertEquals((await bodyOf(await finishBot(post("/f", { match_id: "match-1", actions: [], outcome: "final" }, "good"), human.client))).error, "not_a_bot_match");

  const invented = admin(match({ is_bot: true, black: null }));
  assertEquals((await bodyOf(await finishBot(post("/f", { match_id: "match-1", actions: ["f2f3"], outcome: "final" }, "good"), invented.client))).error, "not_finished");
  assertEquals(invented.calls.rpc.length, 0);

  const timed = admin(match({ is_bot: true, black: null }));
  const timeout = await finishBot(post("/f", { match_id: "match-1", actions: [], outcome: "timeout" }, "good"), timed.client);
  assertEquals(timeout.status, 200);
  assertEquals(timed.calls.rpc[0].args.p_result, "timeout");
  assertEquals(timed.calls.rpc[0].args.p_winner, "black");

  const quit = admin(match({ is_bot: true, black: null }));
  await finishBot(post("/f", { match_id: "match-1", actions: ["f2f3"], outcome: "resigned" }, "good"), quit.client);
  assertEquals(quit.calls.rpc[0].args.p_result, "resigned");
  assertEquals(quit.calls.rpc[0].args.p_winner, "black");

  const mate = admin(match({ is_bot: true, white: BLACK, black: WHITE }));
  const done = await finishBot(post("/f", {
    match_id: "match-1",
    actions: ["f2f3", "e7e5", "g2g4", "d8h4"],
    outcome: "final",
  }, "good"), mate.client);
  assertEquals(done.status, 200);
  assertEquals(mate.calls.rpc[0].args.p_result, "mate");
  assertEquals(mate.calls.rpc[0].args.p_winner, "black");
});

Deno.test("delete-account löscht nur den angemeldeten Spieler", async () => {
  const guest = admin(match());
  assertEquals((await bodyOf(await deleteAccount(post("/d", {}), guest.client))).error, "not_authenticated");
  assertEquals(guest.calls.deleted.length, 0);

  const mine = admin(match());
  const res = await deleteAccount(post("/d", { user_id: BLACK }, "good"), mine.client);
  assertEquals(res.status, 200);
  assertEquals(mine.calls.deleted, [WHITE]);
});
