<div class="main-content">
    <div class="content-header">
        <h1>Dashboard</h1>
    </div>
    <div class="content-cards">
        <div class="card">
            <h3>Total Users</h3>
            <p class="card-value">1,500</p>
        </div>
        <div class="card">
            <h3>Total Products</h3>
            <p class="card-value">250</p>
        </div>
        <div class="card">
            <h3>Total Orders</h3>
            <p class="card-value">3,750</p>
        </div>
        <div class="card">
            <h3>Revenue</h3>
            <p class="card-value">$15,000</p>
        </div>
    </div>
</div>



<style>

    .content-cards {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        gap: 24px;
    }

    .card {
        background: var(--color-surface);
        padding: 24px;
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.04);
        transition: transform 0.2s ease, box-shadow 0.2s ease;
    }

    .card:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.08);
    }

    .card h3 {
        color: var(--color-text-primary);
        font-size: 16px;
        font-weight: 500;
        opacity: 0.8;
        margin-bottom: 12px;
    }
    .card-value {
        color: var(--color-text-primary);
        font-size: 28px;
        font-weight: 700;
        font-family: 'Georgia', serif;
        margin-top: 8px;
        background: linear-gradient(45deg, var(--color-text-primary), #34495e);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        letter-spacing: -0.5px;
    }

    .card h3 {
        color: var(--color-text-primary);
        font-size: 14px; /* slightly smaller to create contrast */
        font-weight: 500;
        opacity: 0.7;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    @media (max-width: 768px) {
        .content-cards {
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
        }

        .card {
            padding: 20px;
        }

        .content-header h1 {
            font-size: 20px;
        }

        .card-value {
            font-size: 24px;
        }
    }
</style>
