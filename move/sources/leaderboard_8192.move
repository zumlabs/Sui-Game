module ethos::leaderboard_8192 {
    use std::vector;

    use sui::object::{Self, ID, UID};
    use sui::tx_context::{TxContext};
    use sui::transfer;

    use ethos::game_8192::{Self, Game8192};

    const ENotALeader: u64 = 0;
    const ELowTile: u64 = 1;
    const ELowScore: u64 = 2;

    #[test_only]
    friend ethos::leaderboard_8192_tests;

    struct Leaderboard8192 has key, store {
        id: UID,
        max_leaderboard_game_count: u64,
        top_games: vector<TopGame8192>,
        min_tile: u64,
        min_score: u64
    }

    struct TopGame8192 has store, copy, drop {
        game_id: ID,
        leader_address: address,
        top_tile: u64,
        score: u64
    }

    fun init(ctx: &mut TxContext) {
        create(ctx);
    }

    // ENTRY FUNCTIONS //

    public entry fun create(ctx: &mut TxContext) {
        let leaderboard = Leaderboard8192 {
            id: object::new(ctx),
            max_leaderboard_game_count: 50,
            top_games: vector<TopGame8192>[],
            min_tile: 0,
            min_score: 0
        };

        transfer::share_object(leaderboard);
    }

    public entry fun submit_game(game: &mut Game8192, leaderboard: &mut Leaderboard8192) {
        let top_tile = *game_8192::top_tile(game);
        let score = *game_8192::score(game);

        assert!(top_tile >= leaderboard.min_tile, ELowTile);
        assert!(score > leaderboard.min_score, ELowScore);

        let leader_address = *game_8192::player(game);
        let game_id = game_8192::id(game);

        let top_game = TopGame8192 {
            game_id,
            leader_address,
            score: *game_8192::score(game),
            top_tile: *game_8192::top_tile(game)
        };

        add_top_game_sorted(leaderboard, top_game);
    }

    // PUBLIC ACCESSOR FUNCTIONS //

    public fun game_count(leaderboard: &Leaderboard8192): u64 {
        vector::length(&leaderboard.top_games)
    }

    public fun top_games(leaderboard: &Leaderboard8192): &vector<TopGame8192> {
        &leaderboard.top_games
    }

    public fun top_game_at(leaderboard: &Leaderboard8192, index: u64): &TopGame8192 {
        vector::borrow(&leaderboard.top_games, index)
    }

    public fun top_game_at_has_id(leaderboard: &Leaderboard8192, index: u64, game_id: ID): bool {
        let top_game = top_game_at(leaderboard, index);
        top_game.game_id == game_id
    }

    public fun top_game_game_id(top_game: &TopGame8192): ID {
        top_game.game_id
    }

    public fun top_game_top_tile(top_game: &TopGame8192): &u64 {
        &top_game.top_tile
    }

    public fun top_game_score(top_game: &TopGame8192): &u64 {
        &top_game.score
    }

    public fun min_tile(leaderboard: &Leaderboard8192): &u64 {
        &leaderboard.min_tile
    }

    public fun min_score(leaderboard: &Leaderboard8192): &u64 {
        &leaderboard.min_score
    }

    fun add_top_game_sorted(leaderboard: &mut Leaderboard8192, top_game: TopGame8192) {
        let top_games = leaderboard.top_games;
        let top_games_length = vector::length(&top_games);

        let index = 0;
        while (index < top_games_length) {
            let current_top_game = vector::borrow(&top_games, index);
            if (top_game.game_id == current_top_game.game_id) {
                vector::swap_remove(&mut top_games, index);
                break
            };
            index = index + 1;
        };

        vector::push_back(&mut top_games, top_game);

        top_games = merge_sort_top_games(top_games); 
        top_games_length = vector::length(&top_games);

        if (top_games_length > leaderboard.max_leaderboard_game_count) {
            vector::pop_back(&mut top_games);
            top_games_length  = top_games_length - 1;
        };

        if (top_games_length >= leaderboard.max_leaderboard_game_count) {
            let bottom_game = vector::borrow(&top_games, top_games_length - 1);
            leaderboard.min_tile = bottom_game.top_tile;
            leaderboard.min_score = bottom_game.score;
        };

        leaderboard.top_games = top_games;
    }

    public(friend) fun merge_sort_top_games(top_games: vector<TopGame8192>): vector<TopGame8192> {
        let top_games_length = vector::length(&top_games);
        if (top_games_length == 1) {
            return top_games
        };

        let mid = top_games_length / 2;

        let right = vector<TopGame8192>[];
        let index = 0;
        while (index < mid) {
            vector::push_back(&mut right, vector::pop_back(&mut top_games));
            index = index + 1;
        };

        let sorted_left = merge_sort_top_games(top_games);
        let sorted_right = merge_sort_top_games(right);
        merge(sorted_left, sorted_right)
    }

    public(friend) fun merge(left: vector<TopGame8192>, right: vector<TopGame8192>): vector<TopGame8192> {
        vector::reverse(&mut left);
        vector::reverse(&mut right);

        let result = vector<TopGame8192>[];
        while (!vector::is_empty(&left) && !vector::is_empty(&right)) {
            let left_item = vector::borrow(&left, vector::length(&left) - 1);
            let right_item = vector::borrow(&right, vector::length(&right) - 1);

            if (left_item.top_tile > right_item.top_tile) {
                vector::push_back(&mut result, vector::pop_back(&mut left));
            } else if (left_item.top_tile < right_item.top_tile) {
                vector::push_back(&mut result, vector::pop_back(&mut right));
            } else {
                if (left_item.score > right_item.score) {
                    vector::push_back(&mut result, vector::pop_back(&mut left));
                } else {
                    vector::push_back(&mut result, vector::pop_back(&mut right));
                }
            };
        };

        vector::reverse(&mut left);
        vector::reverse(&mut right);
        
        vector::append(&mut result, left);
        vector::append(&mut result, right);
        result
    }
    

    // TEST FUNCTIONS //

    #[test_only]
    use sui::test_scenario::{Self, Scenario};

    #[test_only]
    public fun blank_leaderboard(scenario: &mut Scenario, max_leaderboard_game_count: u64, min_tile: u64, min_score: u64) {
        let ctx = test_scenario::ctx(scenario);
        let leaderboard = Leaderboard8192 {
            id: object::new(ctx),
            max_leaderboard_game_count: max_leaderboard_game_count,
            top_games: vector<TopGame8192>[],
            min_tile: min_tile,
            min_score: min_score
        };

        transfer::share_object(leaderboard)
    }

    #[test_only]
    public fun top_game(scenario: &mut Scenario, leader_address: address, top_tile: u64, score: u64): TopGame8192 {
        let ctx = test_scenario::ctx(scenario);
        let object = object::new(ctx);
        let game_id = object::uid_to_inner(&object);
        sui::test_utils::destroy<sui::object::UID>(object);
        TopGame8192 {
            game_id,
            leader_address,
            top_tile,
            score
        }
    }
}