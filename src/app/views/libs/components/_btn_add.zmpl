@args title: []const u8

<button class="btn-add">
    @partial libs/icons/add_plus
    Add {{title}}
</button>

<style>

    .btn-add {
         display: flex;
         align-items: center;
         gap: 8px;
         padding: 12px 24px;
         white-space: nowrap;
     }


     @media (max-width: 480px) {
         .btn-add {
             padding: 8px 16px;
         }
     }

</style>
