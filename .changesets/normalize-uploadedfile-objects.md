---
bump: patch
type: change
---

Normalize Rack and Rails `UploadedFile` objects. Instead of displaying the Ruby class name, it will now show object details like the filename and content type.

```
# Before
#<Rack::Multipart::UploadedFile>
#<ActionDispatch::Http::UploadedFile>

# After
#<Rack::Multipart::UploadedFile original_filename: "uploaded_file.txt", content_type: "text/plain">
#<ActionDispatch::Http::UploadedFile original_filename: "uploaded_file.txt", content_type: "text/plain">
```
