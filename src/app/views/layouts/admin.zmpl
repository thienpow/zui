<!DOCTYPE html>
<html lang="en">
<head>
<title>zUI Portal</title>
@partial layouts/meta
@partial layouts/htmx

@zig {
    if (zmpl.getT(.string, "dark")) |dark|{
        if (std.mem.eql(u8, dark, "checked")) {
            @partial libs/styles/themes/default_dark
        } else {
            @partial libs/styles/themes/default
        }
    }
}
@partial libs/styles/themes/core
<style>
    main {
        background: inherit;
        margin-top: 80px;
        margin-left: 270px;
        margin-right: 20px;
        transition: margin-left 0.3s ease;
    }

    .main-content {
        background: var(--color-surface);
        padding: 30px;
        border-radius: 15px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        margin-bottom: 80px;
    }

    .content-header h1 {
        font-family: 'Georgia', serif;
        color: var(--color-text-primary);
        font-size: 28px;
        font-weight: 600;
        margin-bottom: 30px;
    }


    /* Media query for small screens */
    @media (max-width: 768px) {
        main {
            margin-left: 20px;
            margin-right: 20px;
        }
    }

    @media (max-width: 480px) {
        main {
            margin-left: 6px;
            margin-right: 6px;
        }
    }
</style>

</head>
<body>
    @partial layouts/admin/sidebar
    @partial layouts/admin/topbar
    <main>
        {{zmpl.content}}
    </main>
</body>
</html>
