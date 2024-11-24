<div class="nav-links">
    @partial layouts/landing/menu_items
</div>



<style>
    .nav-links {
        display: flex;
        gap: 2rem;
    }

    .nav-links a {
        color: white;
        text-decoration: none;
        transition: color 0.3s;
        cursor: pointer;
    }

    .nav-links a:hover {
        color: #ddd;
    }

    @media (max-width: 768px) {
        .nav-links {
            display: none;
        }
    }
</style>
