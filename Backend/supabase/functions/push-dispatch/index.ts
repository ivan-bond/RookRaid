import { handle } from "./handle.ts";

// Only the request: Deno.serve passes connection info as the second argument, which would
// take the place of the database client that handle() otherwise creates itself.
Deno.serve((req) => handle(req));
