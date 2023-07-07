module ethos::game_board_8192 {
    use std::vector;
    
    friend ethos::game_8192;
    #[test_only]
    friend ethos::game_8192_tests;
    
    #[test_only]
    friend ethos::leaderboard_8192_tests;

    const LEFT: u64 = 0;
    const RIGHT: u64 = 1;
    const UP: u64 = 2;
    const DOWN: u64 = 3;
    const ALL: u64 = 4;

    const EMPTY: u64 = 0;
    const TILE2: u64 = 1;
    const TILE4: u64 = 2;
    const TILE8: u64 = 3;
    const TILE16: u64 = 4;
    const TILE32: u64 = 5;
    const TILE64: u64 = 6;
    const TILE128: u64 = 7;
    const TILE256: u64 = 8;
    const TILE512: u64 = 9;
    const TILE1024: u64 = 10;
    const TILE2048: u64 = 11;
    const TILE4096: u64 = 12;
    const TILE8192: u64 = 13;

    const ESpaceEmpty: u64 = 0;
    const ESpaceNotEmpty: u64 = 1;
    const ENoEmptySpaces: u64 = 2;
    const EGameOver: u64 = 3;

    const ROW_COUNT: u8 = 4;
    const COLUMN_COUNT: u8 = 4;

    struct GameBoard8192 has store, copy, drop{
        packed_spaces: u64,
        score: u64,
        last_tile: vector<u64>,
        top_tile: u64,
        game_over: bool
    }

    struct SpacePosition has copy, drop {
        row: u8,
        column: u8
    }

    public fun left(): u64 { LEFT }
    public fun right(): u64 { RIGHT }
    public fun up(): u64 { UP }
    public fun down(): u64 { DOWN }

    // PUBLIC FRIEND FUNCTIONS //

    public(friend) fun default(random: vector<u8>): GameBoard8192 {
        let packed_spaces: u64 = 0;

        let row1 = (*vector::borrow(&random, 1) % 2);
        let column1 = (*vector::borrow(&random, 2) % 4);
        packed_spaces = fill_in_space_at(packed_spaces, row1, column1, TILE2);

        let row2 = ((*vector::borrow(&random, 3) % 2) + 2);
        let column2 = (*vector::borrow(&random, 4) % 4);
        packed_spaces = fill_in_space_at(packed_spaces, row2, column2, TILE2);

        let game_board = GameBoard8192 { 
          packed_spaces, 
          score: 0,
          last_tile: vector[3, 1, (TILE2 as u64)],
          top_tile: TILE2,
          game_over: false
        };

        game_board 
    }

    public(friend) fun move_direction(game_board: &mut GameBoard8192, direction: u64, random: vector<u8>) {
        assert!(!game_board.game_over, 3);
        
        let existing_spaces = *&game_board.packed_spaces;

        let (packed_spaces, top_tile, add) = move_spaces(game_board.packed_spaces, direction);
        game_board.packed_spaces = packed_spaces;

        if (existing_spaces == game_board.packed_spaces) {
            if (!move_possible(game_board)) {
                game_board.game_over = true;
            };
            
            return
        };

        game_board.score = game_board.score + add;

        let new_tile = add_new_tile(game_board, direction, random);
 
        if (new_tile > top_tile) {
            top_tile = new_tile;
        };

        game_board.top_tile = top_tile; 

        if (!move_possible(game_board)) {
            game_board.game_over = true;
        };
    }

    public(friend) fun packed_spaces(game_board: &GameBoard8192): &u64 { 
        &game_board.packed_spaces 
    }

    public(friend) fun score(game_board: &GameBoard8192): &u64 { 
        &game_board.score 
    }

    public(friend) fun last_tile(game_board: &GameBoard8192): &vector<u64> {
        &game_board.last_tile
    }

    public(friend) fun top_tile(game_board: &GameBoard8192): &u64 {
        &game_board.top_tile
    }

    public(friend) fun game_over(game_board: &GameBoard8192): &bool {
        &game_board.game_over
    }

    public(friend) fun row_count(): u8 {
        ROW_COUNT
    }

    public(friend) fun column_count(): u8 {
        COLUMN_COUNT
    }

    public(friend) fun space_at(packed_spaces: u64, row_index: u8, column_index: u8): u64 {
        (packed_spaces >> (row_index * COLUMN_COUNT + column_index) * ROW_COUNT) & 0xF
    }

    public(friend) fun board_space_at(game_board: &GameBoard8192, row_index: u8, column_index: u8): u64 {
        space_at(game_board.packed_spaces, row_index, column_index)
    }

    public(friend) fun empty_space_positions(game_board: &GameBoard8192, direction: u64): vector<SpacePosition> {
        let empty_spaces = vector<SpacePosition>[];

        let rows = ROW_COUNT;
        let columns = COLUMN_COUNT;
        let starter_row = 0;
        let starter_column = 0;
        
        if (direction != ALL) {
            if (direction == LEFT) {
                starter_row = 0;
                starter_column = 3;
            } else if (direction == RIGHT) {
                columns = 1;
            } else if (direction == UP) {
                starter_row = 3;
                starter_column = 0;
            } else if (direction == DOWN) {
                rows = 1;
            };
        };
        
        let row = starter_row;
        while (row < rows) {
          let column = starter_column;
          while (column < columns) {
            let space = board_space_at(game_board, row, column);
            if (space == EMPTY) {
              vector::push_back(&mut empty_spaces, SpacePosition { row, column })
            };
            column = column + 1;
          };
          row = row + 1;
        };

        empty_spaces
    }

    public(friend) fun empty_space_count(game_board: &GameBoard8192): u64 {
        vector::length(&empty_space_positions(game_board, ALL))
    }


    // PRIVATE FUNCTIONS //

    fun replace_value_at(packed_spaces: u64, row_index: u8, column_index: u8, value: u64): u64 {
        let shift_bits = (ROW_COUNT * (column_index + row_index * COLUMN_COUNT));
        let mask = (0xF << shift_bits) ^ 0xFFFFFFFFFFFFFFFF;
        (packed_spaces & mask) | (value << shift_bits)
    }

    fun move_possible(game_board: &GameBoard8192): bool {
        let rows = ROW_COUNT;
        let columns = COLUMN_COUNT;
        
        let row = 0;
        while (row < rows) {
            let column = 0;
            while (column < columns) {
                let space = board_space_at(game_board, row, column);
                if (space == EMPTY) {
                    return true
                };

                if (column < columns - 1) {
                    let right_space = board_space_at(game_board, row, column + 1);
                    if (right_space == EMPTY || right_space == space) {
                        return true
                    }
                };

                if (row < rows - 1) {
                    let down_space = board_space_at(game_board, row + 1, column);
                    if (down_space == EMPTY || down_space == space) {
                        return true
                    }
                };
                
                column = column + 1;
            };
            row = row + 1;
        };

        return false
    }

    fun add_new_tile(game_board: &mut GameBoard8192, direction: u64, random: vector<u8>): u64 {
        let empty_spaces = empty_space_positions(game_board, direction);
        let empty_spaces_count = vector::length(&empty_spaces);
        assert!(empty_spaces_count > 0, ENoEmptySpaces);

        let tile = TILE2;
        let top = *top_tile(game_board);
        if (top >= TILE8192 && *vector::borrow(&random, 0) % 6 == 0) {
            tile = TILE32; 
        } else if (top >= TILE4096 && *vector::borrow(&random, 0) % 5 == 0) {
            tile = TILE16; 
        } else if (top >= TILE2048 && *vector::borrow(&random, 0) % 4 == 0) {
            tile = TILE8; 
        } else if (*vector::borrow(&random, 0) % 4 == 0) {
            tile = TILE4; 
        };

        let random_empty_position = (*vector::borrow(&random, 1) as u64) % empty_spaces_count;
        let empty_space = vector::borrow(&empty_spaces, random_empty_position);

        let packed_spaces = fill_in_space_at(game_board.packed_spaces, empty_space.row, empty_space.column, tile);
        game_board.packed_spaces = packed_spaces;
        game_board.last_tile = vector[(empty_space.row as u64), (empty_space.column as u64), (tile as u64)];

        tile
    }

    fun fill_in_space_at(packed_spaces: u64, row_index: u8, column_index: u8, value: u64): u64 {
        packed_spaces | value << (ROW_COUNT * (column_index + row_index * COLUMN_COUNT))
    }

    fun spaces_at(packed_spaces: u64, row_index: u8, column_index: u8, direction: u64): (u64, u64, u64, u64) {
        let space1: u64;
        let space2: u64;
        let space3: u64;
        let space4: u64;
        if (direction == LEFT) {
            space1 = space_at(packed_spaces, row_index, 0);
            space2 = space_at(packed_spaces, row_index, 1);
            space3 = space_at(packed_spaces, row_index, 2);
            space4 = space_at(packed_spaces, row_index, 3);
        } else if (direction == RIGHT) {
            space1 = space_at(packed_spaces, row_index, 3);
            space2 = space_at(packed_spaces, row_index, 2);
            space3 = space_at(packed_spaces, row_index, 1);
            space4 = space_at(packed_spaces, row_index, 0);
        } else if (direction == UP) {
            space1 = space_at(packed_spaces, 0, column_index);
            space2 = space_at(packed_spaces, 1, column_index);
            space3 = space_at(packed_spaces, 2, column_index);
            space4 = space_at(packed_spaces, 3, column_index);
        } else {
            space1 = space_at(packed_spaces, 3, column_index);
            space2 = space_at(packed_spaces, 2, column_index);
            space3 = space_at(packed_spaces, 1, column_index);
            space4 = space_at(packed_spaces, 0, column_index);
        };

        (space1, space2, space3, space4)
    }

    fun save_spaces(packed_spaces: u64, row_index: u8, column_index: u8, space1: u64, space2: u64, space3: u64, space4: u64, space1Changed: bool, space2Changed: bool, space3Changed: bool, space4Changed: bool, direction: u64): u64 {
        if (direction == LEFT) {
            if (space1Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 0, space1);
            if (space2Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 1, space2);
            if (space3Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 2, space3);
            if (space4Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 3, space4);
        } else if (direction == RIGHT) {
            if (space1Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 3, space1);
            if (space2Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 2, space2);
            if (space3Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 1, space3);
            if (space4Changed) packed_spaces = replace_value_at(packed_spaces, row_index, 0, space4);
        } else if (direction == UP) {
            if (space1Changed) packed_spaces = replace_value_at(packed_spaces, 0, column_index, space1);
            if (space2Changed) packed_spaces = replace_value_at(packed_spaces, 1, column_index, space2);
            if (space3Changed) packed_spaces = replace_value_at(packed_spaces, 2, column_index, space3);
            if (space4Changed) packed_spaces = replace_value_at(packed_spaces, 3, column_index, space4);
        } else if (direction == DOWN) {
            if (space1Changed) packed_spaces = replace_value_at(packed_spaces, 3, column_index, space1);
            if (space2Changed) packed_spaces = replace_value_at(packed_spaces, 2, column_index, space2);
            if (space3Changed) packed_spaces = replace_value_at(packed_spaces, 1, column_index, space3);
            if (space4Changed) packed_spaces = replace_value_at(packed_spaces, 0, column_index, space4);
        };

        packed_spaces
    }

    fun move_spaces(packed_spaces: u64, direction: u64): (u64, u64, u64) {
        let current_direction = direction;
        
        let top_tile: u64 = 1;
        let score_addition: u64 = 0;

        let relevant_row = 0;
        if (current_direction == DOWN) {
            relevant_row = ROW_COUNT - 1;
        };

        let relevant_column = 0;
        if (current_direction == RIGHT) {
            relevant_column = COLUMN_COUNT  - 1;
        };
                
        let last_empty_index: u8 = 99;

        let (space1, space2, space3, space4) = spaces_at(
            packed_spaces, 
            relevant_row, 
            relevant_column, 
            current_direction
        );

        let original_space1 = space1;
        let original_space2 = space2;
        let original_space3 = space3;
        let original_space4 = space4;

        let space_index = 1;
        let next_space_index = 2;

        while (true) {
            if (next_space_index > ROW_COUNT) {
                packed_spaces = save_spaces(
                    packed_spaces, 
                    relevant_row, 
                    relevant_column, 
                    space1, 
                    space2, 
                    space3, 
                    space4,
                    original_space1 != space1,
                    original_space2 != space2,
                    original_space3 != space3,
                    original_space4 != space4, 
                    current_direction
                );

                relevant_row = next_row(relevant_row, current_direction);
                relevant_column = next_column(relevant_column, current_direction);

                if (!valid_row(relevant_row) || !valid_column(relevant_column)) {
                    break
                };

                (space1, space2, space3, space4) = spaces_at(
                    packed_spaces, 
                    relevant_row, 
                    relevant_column, 
                    current_direction
                );                        

                last_empty_index = 99;

                original_space1 = space1;
                original_space2 = space2;
                original_space3 = space3;
                original_space4 = space4;

                space_index = 1; 
                next_space_index = 2;
            };

            let space;
            if (space_index == 1) { space = space1 }
            else if (space_index == 2) { space = space2 }
            else if (space_index == 3) { space = space3 }
            else { space = space4 };

            let next_space;
            if (next_space_index == 1) { next_space = space1 }
            else if (next_space_index == 2) { next_space = space2 }
            else if (next_space_index == 3) { next_space = space3 }
            else { next_space = space4 };

            if (space == EMPTY) {
                last_empty_index = space_index;
            } else if (space > top_tile) {
                top_tile = space;
            };

            if (next_space == EMPTY) {
                if (last_empty_index == 99) {
                    last_empty_index = next_space_index;
                };
            } else {
                if (next_space == space) {
                    let score = 2;
                    let space_steps = space;
                    while (space_steps > 0) {
                        score = score * 2;
                        space_steps = space_steps - 1;
                    };
                    score_addition = score_addition + score;

                    if (space + 1 > top_tile) {
                        top_tile = space + 1;
                    };

                    if (space_index == 1) {
                        space1 = space + 1;
                    } else if (space_index == 2) {
                        space2 = space + 1;
                    } else if (space_index == 3) {
                        space3 = space + 1;
                    } else {
                        space4 = space + 1;
                    };

                    if (next_space_index == 1) {
                        space1 = EMPTY;
                    } else if (next_space_index == 2) {
                        space2 = EMPTY;
                    } else if (next_space_index == 3) {
                        space3 = EMPTY;
                    } else {
                        space4 = EMPTY;
                    };

                    if (last_empty_index != 99) {
                        space_index = last_empty_index;
                    } else {
                        space_index = next_space_index;
                    };

                    next_space_index = space_index;
                } else if (next_space != space) {
                    if (last_empty_index != 99) {

                        if (last_empty_index == 1) {
                            space1 = next_space;
                        } else if (last_empty_index == 2) {
                            space2 = next_space;
                        } else if (last_empty_index == 3) {
                            space3 = next_space;
                        } else {
                            space4 = next_space;
                        };
                        
                        if (next_space_index == 1) {
                            space1 = EMPTY;
                        } else if (next_space_index == 2) {
                            space2 = EMPTY;
                        } else if (next_space_index == 3) {
                            space3 = EMPTY;
                        } else {
                            space4 = EMPTY;
                        };
                        

                        space_index = last_empty_index;
                        next_space_index = space_index;
                        last_empty_index = 99;
                    } else {
                        space_index = next_space_index;
                    }               
                };
            };

            next_space_index = next_space_index + 1;
        }; 

        (packed_spaces, top_tile, score_addition)
    }

    fun next_row(row: u8, direction: u64): u8 {
        if (direction == RIGHT || direction == LEFT) {
            return row + 1
        };

        row
    }

    fun next_column(column: u8, direction: u64): u8 {
        if (direction == DOWN || direction == UP) {
            return column + 1
        };

        column
    }

    fun valid_row(row: u8): bool {
        row >= 0 && row < ROW_COUNT
    }

    fun valid_column(column: u8): bool {
        column >= 0 && column < COLUMN_COUNT
    }

    // TESTS //

    // In here due to number of constants

    #[test_only]
    public fun print_packed_spaces(packed_spaces: u64) {
        let row_index = 0;
        while (row_index < ROW_COUNT) {
            let column_index = 0;
            let printable_row = vector<u64>[];
            while (column_index < COLUMN_COUNT) {
                let space = space_at(packed_spaces, row_index, column_index);
                vector::push_back(&mut printable_row, space);
                column_index = column_index + 1;
            };

            std::debug::print(&printable_row);
            row_index = row_index + 1;
        }
    }

    #[test_only]
    public fun print_board(board: &GameBoard8192) {        
        print_packed_spaces(board.packed_spaces);
    }

    #[test_only]
    fun pack_spaces(spaces: vector<u64>): u64 {
        let packed_spaces = 0;
        let rows = ROW_COUNT;
        let columns = COLUMN_COUNT;
        
        let row=0;
        while (row < rows) {
            let column=0;
            while (column < columns) {
                let index = (row * columns) + column;
                let space = *vector::borrow<u64>(&spaces, (index as u64));
                packed_spaces = packed_spaces | space << ((row * COLUMN_COUNT + column) * ROW_COUNT);
                column = column + 1;
            };
            row = row + 1;
        };

        packed_spaces
    }

    #[test_only]
    fun game_board_matches(game_board: &GameBoard8192, expected_spaces: vector<u64>): bool {
        let expected_packed_spaces = pack_spaces(expected_spaces);
        game_board.packed_spaces == expected_packed_spaces
    }

    #[test]
    fun test_default_game_board() {
        let game_board = default(vector[1,2,3,4,5,6]);
        let empty_space_count = empty_space_count(&game_board);
        assert!(empty_space_count == 14, empty_space_count);
    }

    #[test]
    fun test_move_left() {
        let game_board = default(vector[1,2,3,4,5,6]);
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(2 as u64), (3 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            TILE2, EMPTY, EMPTY, EMPTY,
            EMPTY, EMPTY, EMPTY, EMPTY,
            TILE2, EMPTY, EMPTY, TILE2,
            EMPTY, EMPTY, EMPTY, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move_left__complex() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE16, EMPTY, TILE128, TILE128,
                EMPTY, EMPTY, EMPTY, TILE256,
                EMPTY, TILE8, TILE8, TILE8,
                TILE32, EMPTY, EMPTY, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE128,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(2 as u64), (3 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            TILE16,  TILE256, EMPTY, EMPTY,
            TILE256, EMPTY,   EMPTY, EMPTY,
            TILE16,  TILE8,   EMPTY, TILE2,
            TILE64,  EMPTY,   EMPTY, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move_right() {
        let game_board = default(vector[1,2,3,4,5,6]);
        move_direction(&mut game_board, RIGHT, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(2 as u64), (0 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            EMPTY, EMPTY, EMPTY, TILE2,
            EMPTY, EMPTY, EMPTY, EMPTY,
            TILE2, EMPTY, EMPTY, TILE2,
            EMPTY, EMPTY, EMPTY, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move_right__complex() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE16, EMPTY, TILE128, TILE128,
                EMPTY, TILE256, EMPTY, EMPTY,
                EMPTY, TILE8, TILE8, TILE8,
                TILE32, EMPTY, EMPTY, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE128,
            game_over: false
        };
        move_direction(&mut game_board, RIGHT, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(2 as u64), (0 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            EMPTY, EMPTY, TILE16, TILE256, 
            EMPTY, EMPTY, EMPTY, TILE256,
            TILE2, EMPTY, TILE8, TILE16, 
            EMPTY, EMPTY, EMPTY, TILE64
        ]), 1);
    }

    #[test]
    fun test_move_up() {
        let game_board = default(vector[1,2,3,4,5,6]);
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(3 as u64), (2 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            EMPTY, TILE2, EMPTY, TILE2,
            EMPTY, EMPTY, EMPTY, EMPTY,
            EMPTY, EMPTY, EMPTY, EMPTY,
            EMPTY, EMPTY, TILE2, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move_up__complex() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE16, EMPTY, EMPTY, TILE32,
                EMPTY, EMPTY, TILE8, EMPTY,
                TILE128, TILE256, TILE8, EMPTY,
                TILE128, EMPTY, TILE8, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE256,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(3 as u64), (2 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            TILE16,  TILE256, TILE16, TILE64, 
            TILE256, EMPTY,   TILE8,  EMPTY,
            EMPTY,   EMPTY,   EMPTY,  EMPTY, 
            EMPTY,   EMPTY,   TILE2,  EMPTY
        ]), 1);
    }

    #[test]
    fun test_move_down() {
        let game_board = default(vector[1,2,3,4,5,6]);
        move_direction(&mut game_board, DOWN, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(0 as u64), (2 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            EMPTY, EMPTY, TILE2, EMPTY,
            EMPTY, EMPTY, EMPTY, EMPTY,
            EMPTY, EMPTY, EMPTY, EMPTY,
            EMPTY, TILE2, EMPTY, TILE2
        ]), 1);
    }

    #[test]
    fun test_move_down__complex() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE16, EMPTY, EMPTY, TILE32,
                EMPTY, EMPTY, TILE8, EMPTY,
                TILE128, TILE256, TILE8, EMPTY,
                TILE128, EMPTY, TILE8, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE256,
            game_over: false
        };
        move_direction(&mut game_board, DOWN, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(0 as u64), (2 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
            EMPTY,   EMPTY,   TILE2,  EMPTY, 
            EMPTY,   EMPTY,   EMPTY,  EMPTY,
            TILE16,  EMPTY,   TILE8,  EMPTY, 
            TILE256, TILE256, TILE16, TILE64
        ]), 1);
    }

    #[test]
    fun test_stop_scenario() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE4, TILE2, TILE2, EMPTY,
                TILE2, TILE2, TILE4, TILE8,
                TILE2, TILE2, TILE4, TILE4,
                EMPTY, TILE2, TILE2, TILE4
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE8,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(3 as u64), (2 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
          TILE4, TILE4, TILE2, TILE8, 
          TILE4, TILE4, TILE8, TILE8,
          EMPTY, EMPTY, TILE2, EMPTY, 
          EMPTY, EMPTY, TILE2, EMPTY
        ]), 1);
    }

    #[test]
    fun test_stop_scenario__left() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE4, TILE2, TILE2, EMPTY,
                TILE2, TILE2, TILE4, TILE8,
                TILE2, TILE2, TILE4, TILE4,
                TILE16, TILE2, TILE2, TILE4
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE16,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(2 as u64), (3 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
          TILE4,  TILE4, EMPTY, EMPTY, 
          TILE4,  TILE4, TILE8, EMPTY,
          TILE4,  TILE8, EMPTY, TILE2, 
          TILE16, TILE4, TILE4, EMPTY
        ]), 1);
    }

    #[test]
    fun test_stop_scenario__up_inward() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE4, TILE2, EMPTY, EMPTY,
                TILE4, TILE2, EMPTY, EMPTY,
                TILE8, TILE4, EMPTY, EMPTY,
                EMPTY, TILE8, EMPTY, EMPTY
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE8,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(last_tile(&game_board) == &vector[(3 as u64), (2 as u64), (1 as u64)], 1);
        assert!(game_board_matches(&game_board, vector[
          TILE8, TILE4, EMPTY, EMPTY, 
          TILE8, TILE4, EMPTY, EMPTY,
          EMPTY, TILE8, EMPTY, EMPTY, 
          EMPTY, EMPTY, TILE2, EMPTY
        ]), 1);
    }

    #[test]
    #[expected_failure(abort_code = EGameOver)]
    fun test_can_not_move_if_game_over() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE128, TILE256,
                TILE512, TILE1024, EMPTY, TILE512,
                TILE4, TILE8, TILE16, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE8,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);

        assert!(*game_over(&game_board), 1);

        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
    }  

    #[test]
    fun test_game_not_over_if_move_can_be_made() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE2, TILE64, TILE128, TILE256,
                TILE512, TILE1024, EMPTY, TILE2,
                TILE4, TILE8, TILE4, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE8,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);

        assert!(!*game_over(&game_board), 1);
    }

    #[test]
    fun test_move_possible() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE128, TILE256,
                TILE512, TILE1024, EMPTY, TILE512,
                TILE4, TILE8, TILE4, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        assert!(move_possible(&game_board), 1);
    }

    #[test]
    fun test_move_possible_no_move_possible() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE128, TILE32,
                TILE512, TILE1024, TILE16, TILE512,
                TILE2, TILE4, TILE8, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        assert!(!move_possible(&game_board), 1);
    }

    #[test]
    fun test_move_possible_move_possible_down() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE128, TILE256,
                TILE512, TILE1024, TILE16, TILE512,
                TILE4, TILE8, TILE16, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        assert!(move_possible(&game_board), 1);
    }

    #[test]
    fun test_move_possible_move_possible_right() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE128, TILE256,
                TILE512, TILE1024, TILE16, TILE16,
                TILE4, TILE8, TILE2, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        assert!(move_possible(&game_board), 1);
    }

    #[test]
    fun test_move_possible_move_possible_left() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE128, TILE256,
                TILE512, TILE16, TILE16, TILE512,
                TILE4, TILE8, TILE2, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        assert!(move_possible(&game_board), 1);
    }

    #[test]
    fun test_move_possible_move_possible_up() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, TILE64, TILE16, TILE256,
                TILE512, TILE1024, TILE16, TILE512,
                TILE4, TILE8, TILE4, TILE32
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        assert!(move_possible(&game_board), 1);
    }

    #[test]
    fun test_increments_score() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, EMPTY, TILE4, TILE256,
                TILE32, EMPTY, EMPTY, TILE512,
                TILE4, TILE8, TILE4, TILE32
            ]),
            score: 500,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(score(&game_board) == &572, *score(&game_board));

        move_direction(&mut game_board, UP, vector[4,5,6,7,8,9]);
        assert!(score(&game_board) == &588, *score(&game_board));
    } 

    #[test]
    fun test_increments_top_tile() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE4, TILE8, TILE16,
                TILE32, EMPTY, EMPTY, TILE256,
                EMPTY, EMPTY, TILE16, TILE512,
                TILE4, TILE8, TILE4, TILE32
            ]),
            score: 500,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(top_tile(&game_board) == &9, (*top_tile(&game_board) as u64));
    }   

    #[test]
    fun test_increments_top_tile__with_new_tile() {
        let game_board = default(vector[1,2,3,4,5,6]);
        assert!(top_tile(&game_board) == &1, (*top_tile(&game_board) as u64));
        move_direction(&mut game_board, UP, vector[4,5,6,7,8,9]);
        assert!(top_tile(&game_board) == &2, (*top_tile(&game_board) as u64));
    }  

    #[test]
    fun test_increments_top_tile__with_combine() {
        let game_board = default(vector[1,2,3,4,5,6]);
        assert!(top_tile(&game_board) == &1, (*top_tile(&game_board) as u64));
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);
        assert!(top_tile(&game_board) == &2, (*top_tile(&game_board) as u64));
    } 

    #[test]
    fun test_no_tile_added_if_no_move_made() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, EMPTY, EMPTY, EMPTY,
                TILE4, EMPTY, EMPTY, EMPTY,
                TILE8, EMPTY, EMPTY, EMPTY,
                TILE4, EMPTY, EMPTY, EMPTY
            ]),
            score: 500,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(empty_space_count(&game_board) == (12 as u64), empty_space_count(&game_board));
    }  

    #[test]
    fun test_move_high_gas() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE256, TILE256, TILE64, TILE64,
                TILE4, TILE4, TILE8, TILE8,
                TILE1024, TILE1024, TILE8, TILE8,
                TILE1024, TILE1024, TILE8, TILE8
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE512,    TILE128,  EMPTY,   EMPTY,
            TILE8,      TILE16,   EMPTY,   EMPTY,
            TILE2048,   TILE16,   EMPTY,   TILE2,
            TILE2048,   TILE16,   EMPTY,   EMPTY
        ]), 1);
    }

    #[test]
    fun test_move__vector_error() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2048, EMPTY, EMPTY, EMPTY,
                TILE512, TILE4, TILE2, EMPTY,
                TILE128, TILE16, TILE4, TILE2,
                TILE16, TILE2, TILE4, TILE2
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE2048,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE2048, TILE4, TILE2, TILE4, 
            TILE512, TILE16, TILE8, EMPTY,
            TILE128, TILE2, EMPTY, EMPTY, 
            TILE16, EMPTY, EMPTY, TILE2
        ]), 1);
    }

    #[test]
    fun test_move__vector_error_2() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                EMPTY, EMPTY, EMPTY, TILE16,
                EMPTY, TILE2, TILE4, TILE256,
                TILE2, TILE4, TILE8, TILE512,
                TILE2, TILE4, TILE8, TILE128
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE512,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE4, TILE2, TILE4, TILE16, 
            EMPTY, TILE8, TILE16, TILE256,
            EMPTY, EMPTY, EMPTY, TILE512, 
            EMPTY, EMPTY, TILE2, TILE128
        ]), 1);
    }

    #[test]
    fun test_move__MovePrimitiveRuntimeError_error() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE8, TILE2, EMPTY, TILE2,
                TILE32, TILE8, TILE8, EMPTY,
                TILE64, TILE16, TILE16, TILE4,
                TILE128, TILE2, TILE2, TILE2
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE128,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE8, TILE4, EMPTY, EMPTY, 
            TILE32, TILE16, EMPTY, EMPTY,
            TILE64, TILE32, TILE4, TILE2, 
            TILE128, TILE4, TILE2, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move__MoveAbortError() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE2, TILE128, TILE4, TILE8,
                TILE8, TILE2, TILE16, TILE16,
                TILE4, TILE64, TILE2, TILE4,
                TILE2, TILE4, TILE8, TILE2
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE128,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[1,2,3,4,5,6]);

        assert!(game_board_matches(&game_board, vector[
            TILE2, TILE128, TILE4, TILE8, 
            TILE8, TILE2, TILE32, TILE2,
            TILE4, TILE64, TILE2, TILE4, 
            TILE2, TILE4, TILE8, TILE2
        ]), 1);
    }

    #[test]
    fun test_move__adds_higher_value_tile_2048() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                EMPTY, EMPTY, TILE2048, EMPTY,
                EMPTY, EMPTY, EMPTY, EMPTY,
                TILE4, EMPTY, EMPTY, EMPTY,
                TILE2, EMPTY, EMPTY, EMPTY
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE2048,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[4,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE2048, EMPTY, EMPTY, EMPTY, 
            EMPTY, EMPTY, EMPTY, EMPTY,
            TILE4, EMPTY, EMPTY, TILE8, 
            TILE2, EMPTY, EMPTY, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move__adds_higher_value_tile_4096() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                EMPTY, EMPTY, TILE4096, EMPTY,
                EMPTY, EMPTY, EMPTY, EMPTY,
                TILE4, EMPTY, EMPTY, EMPTY,
                TILE2, EMPTY, EMPTY, EMPTY
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE4096,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[5,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE4096, EMPTY, EMPTY, EMPTY, 
            EMPTY, EMPTY, EMPTY, EMPTY,
            TILE4, EMPTY, EMPTY, TILE16, 
            TILE2, EMPTY, EMPTY, EMPTY
        ]), 1);
    }

    #[test]
    fun test_move__adds_higher_value_tile_8192() {
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                EMPTY, EMPTY, TILE8192, EMPTY,
                EMPTY, EMPTY, EMPTY, EMPTY,
                TILE4, EMPTY, EMPTY, EMPTY,
                TILE2, EMPTY, EMPTY, EMPTY
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE8192,
            game_over: false
        };
        move_direction(&mut game_board, LEFT, vector[6,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE8192, EMPTY, EMPTY, EMPTY, 
            EMPTY, EMPTY, EMPTY, EMPTY,
            TILE4, EMPTY, EMPTY, TILE32, 
            TILE2, EMPTY, EMPTY, EMPTY
        ]), 1);
    }

    #[test]
    #[expected_failure(abort_code = EGameOver)]
    fun test_game_over_move_error() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE1024, TILE8, TILE4, TILE2,
                TILE512, TILE4, TILE16, TILE4,
                TILE256, TILE32, TILE8, TILE2,
                TILE64, TILE16, TILE2, TILE16
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);

        assert!(*game_over(&game_board), 1);

        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
    }  

    #[test]
    fun test_game_over() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE1024, TILE8, EMPTY, TILE2,
                TILE512, TILE4, TILE16, TILE4,
                TILE256, TILE32, TILE8, TILE128,
                TILE64, TILE16, TILE64, TILE16
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
        assert!(*game_over(&game_board), 1);
    }  

    #[test]
    #[expected_failure(abort_code = EGameOver)]
    fun test_next_move_game_over_move_error() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE1024, TILE8, TILE4, TILE2,
                TILE512, TILE4, TILE16, TILE4,
                EMPTY, TILE32, TILE8, TILE2,
                TILE64, TILE16, TILE2, TILE16
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);

        assert!(*game_over(&game_board), 1);

        move_direction(&mut game_board, UP, vector[1,2,3,4,5,6]);
    }  

    #[test]
    fun test__add_new_tile_error() {        
        let game_board = GameBoard8192 {
            packed_spaces: pack_spaces(vector[
                TILE32, TILE8, TILE8, TILE2,
                TILE8,  TILE4, EMPTY, EMPTY,
                TILE2, EMPTY, EMPTY, EMPTY,
                TILE4, EMPTY, EMPTY, EMPTY
            ]),
            score: 0,
            last_tile: vector[],
            top_tile: TILE1024,
            game_over: false
        };
        move_direction(&mut game_board, DOWN, vector[1,2,3,4,5,6]);
        assert!(game_board_matches(&game_board, vector[
            TILE32, EMPTY, EMPTY, TILE2, 
            TILE8, EMPTY, EMPTY, EMPTY,
            TILE2, TILE8, EMPTY, EMPTY, 
            TILE4, TILE4, TILE8, TILE2
        ]), 1);
    }  
}