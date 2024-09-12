---
bump: patch
type: change
---

Format the Date and Time objects in a human-friendly way. Previously, dates and times stored in sample data, like session data, would be shown as `#<Date>` and `#<Time>`. Now they will show as `#<Date: 2024-09-11>` and `#<Time: Time: 2024-09-12T13:14:15+02:00>` (UTC offset may be different for your time objects depending on the server setting).
