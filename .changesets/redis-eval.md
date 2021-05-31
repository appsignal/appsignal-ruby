---
bump: "patch"
---

Support Redis eval statements better by showing the actual script that was performed. Instead of showing `eval ? ? ?` (for a script with 2 arguments), show `<script> ? ?`, where `<script>` is whatever script was sent to `Redis.new.eval("<script>")`.
