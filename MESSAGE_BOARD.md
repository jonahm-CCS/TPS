# Message Board setup

Apply `db/message_board.sql` to a TPS Supabase project after the TPS schema and seed data. The Message Board uses verified Supabase Auth email/password accounts and a server-managed mapping to TPS employee IDs. Set up each user through your organization's Supabase Auth account provisioning process, then link their verified account through the SQL editor:

```sql
insert into tps_private.board_identities (user_id, employee_id)
select id, '<TPS employee ID>'
from auth.users
where lower(email) = lower('<verified work email>')
  and email_confirmed_at is not null
  and not coalesce(is_anonymous, false);
```

Confirm that one row was inserted. To let a supervisor create or manage their chats, that employee must also have an active `admin` or `supervisor` entry in `tps_private.command_employees`. Use the corresponding employee number when opening Command Center. The older GitHub prototype currently admits test number `365` into Command Center. Match the test supervisor's server-side record to that number when testing this branch.

Employees can open the Message Board from their station and sign in with their own linked account. Leaving the workspace clears the board session. A chat for selected areas follows current area assignments and a chat for selected employees follows the selected IDs. The sidebar counter updates automatically while the page is open. Opening a conversation acknowledges the posts shown.

For a smoke test on an integration database, use a linked supervisor and two linked employees in separate browser sessions. Create a conversation for one employee, send an emoji and attach a test PDF and an existing job number, and verify that only the intended employee sees it. Confirm the unread badge clears when the conversation is opened and the employee can reply. For an area chat, move an employee out of the selected area and confirm the chat disappears from their list.

The hosted TPS release also includes a Message Board shortcut in Notification Center. For branches with the current notification module, use `boardNotificationMarkup()` in its toolbar and call `bindBoardTriggers(root)` after rendering it.
