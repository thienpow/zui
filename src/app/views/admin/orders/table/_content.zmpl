<section><div class="table-section">
    <table class="table">
        <thead>
            <tr>
                <th>Order ID</th>
                <th>Customer</th>
                <th>Date</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td class="order-id">#ORD-2024-1234</td>
                <td class="customer-cell">
                    @partial libs/icons/placeholder_rounded_32
                    <div class="customer-info">
                        <span class="customer-name">John Doe</span>
                        <span class="customer-email">john@example.com</span>
                    </div>
                </td>
                <td>
                    <div class="date-info">
                        <span class="date">Mar 15, 2024</span>
                        <span class="time">14:30 PM</span>
                    </div>
                </td>
                <td class="amount">$299.99</td>
                <td><span class="status-badge processing">Processing</span></td>
                <td class="actions-cell">
                    <button class="action-btn view">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                            <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                    </button>
                    <button class="action-btn edit">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                        </svg>
                    </button>
                </td>
            </tr>
        </tbody>
    </table>
    @partial libs/components/pagination
</div></section>
