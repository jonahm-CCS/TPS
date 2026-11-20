# Message Board setup

Apply `db/message_board.sql` and then `db/message_board_workspace_access.sql` after the TPS schema and seed data. For a fresh sandbox, provision an active `admin` or `supervisor` Command Center record in `tps_private.command_employees` for the test supervisor, and use the corresponding employee number when opening Command Center. The older integration prototype accepts test number `365` at the Command Center entry screen.

The board reuses the current TPS Command Center employee number or Employee Station badge. These identifiers are the prototype access model. The server uses the matching employee record for sender names, enforces conversation audiences, and reserves chat creation and management for Command Center.

For a smoke test, open Command Center and create a conversation for one employee. Open that employee's station in a second browser session, check that the unread count increases, and open the chat and reply with an emoji and a sample attachment. Confirm that another employee cannot open the selected-employee chat. For an area conversation, update a sample employee assignment and confirm that membership follows the new area.

The hosted release also includes a shortcut in Notification Center. Branches with the current notification module can add `boardNotificationMarkup()` in its toolbar and call `bindBoardTriggers(root)` after rendering.
