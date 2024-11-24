<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About - zUI</title>
    <script src="https://unpkg.com/htmx.org@2.0.0/dist/htmx.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                "Helvetica Neue", Arial, sans-serif;
            background-color: #f5f5f5;
            margin: 0;
            padding: 0;
            min-height: 100vh;
        }

        html {
            box-sizing: border-box;
        }

        *,
        *:before,
        *:after {
            box-sizing: inherit;
        }

        /* Additional Utility Classes */
        .text-gradient {
            background: linear-gradient(90deg, #00ffcc, #00ccff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .highlight {
            color: #00ccff;
        }

        main {
            width: 100%;
            margin: 0;
            padding: 0;
        }
    </style>

</head>
<body>
    @partial layouts/landing/header
    <main>{{zmpl.content}}</main>
    @partial layouts/landing/footer
</body>
</html>
