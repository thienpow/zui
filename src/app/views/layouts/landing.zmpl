<!DOCTYPE html>
<html lang="en">
<head>
<title>zUI - BuildFast with Fullstack UIKit</title>
@partial layouts/meta
@partial layouts/htmx

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


    a {
        display: inline-flex;
        align-items: center;
        color: inherit;
        text-decoration: none;
        padding: 4px 8px;
        border-radius: 4px;
        transition: all 0.3s ease;
        position: relative;
        cursor: pointer;
    }

    a:hover {
        color: #0366d6;
        background-color: rgba(3, 102, 214, 0.1);
        transform: translateY(-1px);
    }

</style>
</head>
<body>
    @partial layouts/landing/header
    <main>{{zmpl.content}}</main>
    @partial layouts/landing/footer
</body>
</html>
