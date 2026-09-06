# Real Time Session AHT Tracker — Production

1. Create a Supabase project.
2. Run schema.sql in Supabase SQL Editor.
3. Put your Supabase Project URL and anon/public key into config.js.
4. Enable Email authentication.
5. Create your own account, then make it admin using the final SQL comment in schema.sql.
6. Deploy index.html, config.js and schema.sql is NOT uploaded publicly unless desired; only index.html + config.js are required by the browser.
7. Use HTTPS hosting.

New users become Pending. Admin approves them. Agent Details are stored centrally and synchronized in realtime to approved users.

Never put a Supabase service-role key in config.js.
