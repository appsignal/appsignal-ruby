---
bump: patch
type: fix
---

Fix Rails detection to check for Rails::Railtie presence

Improves Rails detection by checking for Rails::Railtie instead of just the Rails module. 

This prevents loading errors when non-Rails code defines a Rails constant without the full Rails framework.