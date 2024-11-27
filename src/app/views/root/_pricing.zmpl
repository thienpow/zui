<div class="pricing-section">
    <div class="plan basic">
        <h2>Basic</h2>
        <p class="price">Free & Open Source</p>
        <ul class="features">
            <li>✓ Core UI Components</li>
            <li>✓ Responsive Layout System</li>
            <li>✓ HTMX Integration</li>
            <li>✓ Basic Templates</li>
            <li>✓ Community Support</li>
        </ul>
        <a href="https://github.com/thienpow/zui" class="cta-button">Get Started</a>
    </div>

    <div class="plan pro">
        <h2>Pro</h2>
        <p class="price">$100 <span>Lifetime Access</span></p>
        <ul class="features">
            <li>✓ Everything in Basic, plus:</li>
            <li>✓ User Authentication System</li>
            <li>✓ Admin Dashboard</li>
            <li>✓ Database Integration (PostgreSQL)</li>
            <li>✓ Redis Cache Support</li>
            <li>✓ Blog System</li>
            <li>✓ Product Catalog</li>
            <li>✓ Premium Templates</li>
            <li>✓ Docker Compose & K8s Configurations</li>
            <li>✓ Priority Support</li>
        </ul>
        <a href="/pro-access" class="cta-button pro">Upgrade to Pro</a>
    </div>
</div>
<style>
    .pricing-section {
        background: white;
        display: flex;
        justify-content: center;
        gap: 2rem;
        padding: 4rem 2rem;
        max-width: 1200px;
        margin: 0 auto;
        position: relative;
        z-index: 1;
    }

    .plan {
        flex: 1;
        max-width: 400px;
        padding: 2rem;
        border-radius: 12px;
        background: white;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        transition: transform 0.3s ease;
    }

    .plan:hover {
        transform: translateY(-5px);
    }

    .plan.basic {
        border: 1px solid #e0e0e0;
    }

    .plan.pro {
        border: 2px solid #00ccff;
        position: relative;
        background:
            linear-gradient(white, white) padding-box,
            linear-gradient(135deg, #00ffcc, #00ccff) border-box;
    }

    .plan h2 {
        font-size: 1.8rem;
        margin-bottom: 1rem;
        color: #333;
    }

    .plan .price {
        font-size: 2.5rem;
        font-weight: bold;
        margin-bottom: 2rem;
        color: #1a1a1a;
    }

    .plan .price span {
        font-size: 1rem;
        color: #666;
        font-weight: normal;
    }

    .features {
        list-style: none;
        padding: 0;
        margin: 0 0 2rem 0;
    }

    .features li {
        padding: 0.75rem 0;
        color: #555;
        border-bottom: 1px solid #eee;
    }

    .features li:last-child {
        border-bottom: none;
    }

    .cta-button {
        display: inline-block;
        padding: 1rem 2rem;
        border-radius: 6px;
        text-decoration: none;
        font-weight: bold;
        transition: all 0.3s ease;
        text-align: center;
        width: 100%;
        box-sizing: border-box;
    }

    .basic .cta-button {
        background: #1a1a1a;
        color: white;
    }

    .basic .cta-button:hover {
        background: #333;
    }

    .pro .cta-button {
        background: linear-gradient(135deg, #00ffcc, #00ccff);
        color: #1a1a1a;
    }

    .pro .cta-button:hover {
        transform: scale(1.05);
    }


    /* Responsive Design */
    @media (max-width: 768px) {

        .pricing-section {
            flex-direction: column;
            align-items: center;
            gap: 2rem;
        }

        .plan {
            width: 100%;
            max-width: 100%;
        }

        .plan .price {
            font-size: 2rem;
        }
    }
</style>
