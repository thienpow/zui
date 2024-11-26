<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About - zUI</title>
    <script src="https://unpkg.com/htmx.org@2.0.0/dist/htmx.min.js"></script>

    @partial libs/styles/themes/default

    <style>
        main {
            width: 100%;
            margin: 0;
            padding: 0;
        }
    </style>

    <script>

        //code can be removed in production
        //check if user is on 127.0.0.1, if yes, redirect it to locahost
        //this is to accept cookies from localhost
        if (window.location.hostname === "127.0.0.1") {
            window.location.href = "http://localhost:8080/auth/login";
        }
    </script>
</head>
<body>
    <main>{{zmpl.content}}</main>
</body>
</html>
