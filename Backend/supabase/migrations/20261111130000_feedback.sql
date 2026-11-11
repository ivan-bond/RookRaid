-- Rook Raid – feedback from the app (Profile → Feedback).
-- Every message is stored here first, then the edge function `send-feedback` emails it to rookraidchess@gmail.com.
-- Nothing is lost when the email fails, and the table can be read in the Supabase dashboard.
-- Only the edge function (service role) writes here; players never read it.

create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  user_id     uuid references auth.users(id) on delete set null,   -- null for guests without an account
  ip_hash     text not null,                                       -- SHA-256 of the IP, only for the rate limit
  category    text not null check (category in ('bug', 'balance', 'idea', 'other')),
  message     text not null check (char_length(message) between 3 and 4000),
  contact     text check (char_length(contact) <= 200),
  meta        jsonb not null default '{}'::jsonb,                  -- platform, app version, language, name, trophies
  emailed     boolean not null default false
);
create index if not exists feedback_ip_time on public.feedback (ip_hash, created_at desc);
create index if not exists feedback_user_time on public.feedback (user_id, created_at desc);
alter table public.feedback enable row level security;
revoke all on public.feedback from public, anon, authenticated;

-- Stores one message. At most 5 per hour from one device or account, and at most 300 a day in total.
create or replace function public.save_feedback(p_user uuid, p_ip_hash text, p_category text, p_message text,
                                                p_contact text, p_meta jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare fid uuid; msg text := btrim(coalesce(p_message, ''));
begin
  if p_category not in ('bug', 'balance', 'idea', 'other') or char_length(msg) < 3 or char_length(msg) > 4000
     or char_length(coalesce(p_contact, '')) > 200 or coalesce(p_ip_hash, '') = '' then
    raise exception 'invalid';
  end if;
  perform pg_advisory_xact_lock(hashtext('feedback:' || p_ip_hash));
  if (select count(*) from feedback f
       where f.created_at > now() - interval '1 hour'
         and (f.ip_hash = p_ip_hash or (p_user is not null and f.user_id = p_user))) >= 5
     or (select count(*) from feedback f where f.created_at > now() - interval '1 day') >= 300 then
    raise exception 'rate_limited';
  end if;
  insert into feedback (user_id, ip_hash, category, message, contact, meta)
  values (p_user, p_ip_hash, p_category, msg, nullif(btrim(coalesce(p_contact, '')), ''), coalesce(p_meta, '{}'::jsonb))
  returning id into fid;
  return fid;
end $$;
revoke execute on function public.save_feedback(uuid, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.save_feedback(uuid, text, text, text, text, jsonb) to service_role;

create or replace function public.mark_feedback_emailed(p_id uuid)
returns void language sql security definer set search_path = public as $$
  update feedback set emailed = true where id = p_id;
$$;
revoke execute on function public.mark_feedback_emailed(uuid) from public, anon, authenticated;
grant execute on function public.mark_feedback_emailed(uuid) to service_role;
