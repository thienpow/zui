<section><div class="table-section">
    <table class="table">
        <thead>
            <tr>
                <th>Product</th>
                <th>Category</th>
                <th>Price</th>
                <th>Stock</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td class="product-cell">
                    @partial libs/icons/placeholder_square_32
                    <div class="product-info">
                        <span class="product-name">Wireless Headphones</span>
                        <span class="product-sku">#SKU123456</span>
                    </div>
                </td>
                <td>Electronics</td>
                <td>$129.99</td>
                <td>45</td>
                <td><span class="status-badge in-stock">In Stock</span></td>
                <td class="actions-cell">
                    <button class="action-btn edit">
                        @partial libs/icons/edit_pen_paper
                    </button>
                    <button class="action-btn delete">
                        @partial libs/icons/delete_dustbin
                    </button>
                </td>
            </tr>
            <!-- Add more product rows here -->
        </tbody>
    </table>
    @partial libs/components/pagination
</div></section>
