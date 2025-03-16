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
        box-sizing: border-box;
        height: 64px;
        z-index: 100;
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
