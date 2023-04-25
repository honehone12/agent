module agent::token_store {
    use aptos_std::smart_table::{SmartTable};
    use aptos_token::token::{TokenId, Token};

    struct TokenStore has key {
        tokens: SmartTable<TokenId, Token>,
        direct_transfer: bool
    }
}