<!DOCTYPE html>
<html lang="en">
<head>
<head><title>Redirecting...</title></head>
</head>
<body>

    @if (zmpl.getT(.string, "default_redirect_url")) |default_redirect_url|
        <script>
            window.location.href = "{{default_redirect_url}}"
        </script>
    @end

</body>
</html>
