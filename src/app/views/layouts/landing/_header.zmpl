<header>
    <nav>
        @partial libs/components/brand_topbar
        @partial layouts/landing/menu_navbar
    </nav>
</header>
@partial layouts/landing/menu_mobile



<style>
    header {
        background-color: rgba(26, 26, 26, 0.8);
        backdrop-filter: blur(10px);
        -webkit-backdrop-filter: blur(10px);
        color: white;
        padding: 1rem 48px;
        position: fixed;
        width: 100%;
        top: 0;
        z-index: 1000;
        box-sizing: border-box;
        height: 64px;
    }

    header::after {
        content: "";
        position: absolute;
        bottom: 0;
        left: 0;
        right: 0;
        height: 1px;
        background: rgba(255, 255, 255, 0.1);
    }

    nav {
        max-width: 1200px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    @media (max-width: 480px) {
        header {
            padding: 1rem 24px;
        }
    }
</style>
