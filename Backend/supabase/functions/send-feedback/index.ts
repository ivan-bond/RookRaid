import { handle } from "./handle.ts";

// Only the request: Deno.serve passes connection info as the second argument (see delete-account).
Deno.serve((req) => handle(req));
