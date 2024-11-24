<div class="ai-input-container">
    <svg class="ai-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <path d="M12 4C8.68629 4 6 6.68629 6 10C6 13.3137 8.68629 16 12 16C15.3137 16 18 13.3137 18 10C18 6.68629 15.3137 4 12 4Z"/>
        <path d="M9 10H15"/>
        <path d="M12 7V13"/>
        <circle cx="9" cy="9" r="1"/>
        <circle cx="15" cy="9" r="1"/>
        <path d="M6 18L18 18"/>
        <path d="M12 16V20"/>
    </svg>
    <input type="text" class="ai-input" placeholder="Ask AI...">
</div>

<style>
    .ai-input-container {
        position: relative;
        width: 100%;
        max-width: 400px;
    }

    .ai-input {
        width: 100%;
        padding: 12px 20px 12px 45px;
        font-size: 15px;
    }

    .ai-input::placeholder {
        color: var(--color-text-primary);
        opacity: 0.5;
    }

    .ai-icon {
        position: absolute;
        left: 15px;
        top: 50%;
        transform: translateY(-50%);
        width: 20px;
        height: 20px;
        color: var(--color-text-primary);
        opacity: 0.5;
        pointer-events: none;
    }

    /* Optional hover effect */
    .ai-input-container:hover .ai-icon {
        opacity: 0.7;
    }

    .ai-input:focus + .ai-icon {
        opacity: 0.8;
    }
</style>
