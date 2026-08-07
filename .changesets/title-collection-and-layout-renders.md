---
bump: patch
type: change
---

Report which template was rendered for collection and layout render events.

Rendering a template or a partial is reported with the template's path, so you
can tell one from another. Rendering a collection or a layout was reported
without one. Every collection render in an application was recorded as the same
event, however many different partials it rendered, and so was every layout
render.

They now carry the template's path as well. A collection render reports the
partial it rendered for each item in the collection, and a layout render
reports the layout.

This means an application that renders several collections, or several layouts,
now sees one event per template where it used to see one event in total. That
is what makes it possible to tell which of them is the slow one.
