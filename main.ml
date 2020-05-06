(** Exception [InvalidPieceType] is raised if a place command contains a 
    piece type that is not valid. *)
exception InvalidPieceType

(** Exception [InvalidPlacement] is raised if an invalid row and/or column 
    is provided. *)
exception InvalidPlacement

(** [exit_game ()] exits the program. *)
let exit_game () = 
  exit 0

(** [start_regular_game rows cols players connect colors mode] starts a 
    custom game with the arguments given. *)
let start_custom_game rows cols players connect colors mode =
  Game_mechanics.start_game rows cols players connect colors mode

(** [start_regular_game] starts a basic game of size 7x7 with 2 players. *)
let start_regular_game = 
  Game_mechanics.start_game 7 7 2 4 [ANSITerminal.yellow; ANSITerminal.red] 1

(** [parse_helper piece_type tail] is the string representing the [piece_type]
    and the column number of where it should be played from [tail]. 
    Raises [Failure str] if the column is not an int or the piece type is 
    not valid. *)
let parse_helper piece_type tail = 
  let possible_pieces = ["normal"; "anvil"; "wall"; "bomb"; "force"] in
  match tail with 
  | [] -> raise (Failure "")
  | h::_ -> 
    if List.mem piece_type possible_pieces then (piece_type, int_of_string h) 
    else raise InvalidPieceType

(** [parse_object_phrase object_phrase] is the string of the piece type 
    and column number from string list [object_phrase].
    Raises [Failure str] if not a valid int, object_phrase is empty, or a given
    piece type is invalid. *)
let parse_object_phrase object_phrase = 
  match object_phrase with 
  | [] -> raise (Failure "")
  | h::t -> 
    if List.length object_phrase = 1 then ("normal", int_of_string h) 
    else parse_helper h t

(** [load_from_phrase object_phrase] is the load_result from loading in the
    file present in [object_phrase].
    Raises [Command.Malformed] if loading failed or object_phrase is empty. *)
let load_from_phrase object_phrase =
  match object_phrase with 
  | [] -> raise Command.Malformed
  | h::_ -> Save.load h

(** [save_from_phrase state object_phrase] is the save_result from saving the
    [state] in the file present in [object_phrase].
    Raises [Command.Malformed] if saving failed or object_phrase is empty. *)
let save_from_phrase state object_phrase =
  match object_phrase with 
  | [] -> raise Command.Malformed
  | h::_ -> Save.save state h

(** [load_handler object_phrase] is the state from loading in the file in
    [object_phrase].
    Raises [Failure str] if the file could not be loaded, where [str] is the 
    filename. *)
let load_handler object_phrase = 
  match load_from_phrase object_phrase with
  | Save.Load_Success game_state ->
    game_state
  | Save.Load_Failure str -> 
    raise (Failure str)

(** [save_handler state object_phrase] is [true] if the file in [object_phrase]
    was successfully saved, [false] otherwise.
    Raises [Command.Malformed] if saving failed or object_phrase is empty. *)
let save_handler state object_phrase = 
  match save_from_phrase state object_phrase with
  | Save.Save_Success str ->
    Display.pretty_print_string(String.concat "" ["Game saved to file "; str]);
    true
  | Save.Save_Failure str -> 
    Display.pretty_print_string(String.concat "" 
                                  ["Game failed to save to file "; str; 
                                   ", please try again."]);
    false 

(** [check_win_condition state player col] checks to see if a game was won by
    [player] after they made a move in column [col] in [state]. Prints and 
    quits the game on a win or draw, and continues if the game is not over. *)
let check_win_condition state player col = 
  match (Game_mechanics.check_status state player col) with
  | Game_mechanics.Win win_player -> 
    Display.print_board state;
    Display.pretty_print_string(String.concat "" ["Congrats Player "; 
                                                  string_of_int win_player; ", you won!"]);
    exit_game ()
  | Game_mechanics.Draw ->
    Display.print_board state;
    Display.pretty_print_string("Game over! There is a Draw.");
    exit_game ()
  | Game_mechanics.Play -> ()

(** [get_piece_player state player] is the [player] that the next piece should 
    represent in [state]. This is the current player unless the last piece was 
    a force, in which case it is the previous player. *)
let get_piece_player state player = 
  if Game_mechanics.is_forced state then 
    Game_mechanics.get_prev_player_turn state
  else player

(** [place_piece state object_phrase player] is the new state after a piece 
    has been placed for the given [player] at the column in [object_phrase]. 
    The new state is the same as the current state if the move is invalid. *)
let place_piece state object_phrase player = 
  try 
    let piece_and_col = parse_object_phrase object_phrase in
    let piece_type = fst piece_and_col in
    let col = snd piece_and_col in
    let piece_player = get_piece_player state player in

    let piece = Game_mechanics.create_piece piece_type piece_player in
    let move_result = Game_mechanics.move state col piece in
    match move_result with
    | Game_mechanics.Valid new_state -> 
      (check_win_condition new_state piece_player col);
      new_state
    | Game_mechanics.Invalid -> raise InvalidPlacement
  with
  | Failure _ -> 
    Display.pretty_print_string("Invalid command. Please try again.");
    state
  | InvalidPieceType ->
    Display.pretty_print_string("Invalid piece type. Please try again.");
    state
  | InvalidPlacement ->
    Display.pretty_print_string("Invalid column number. Please try again.");
    state

(** [place_bomb state] is the new state from the user placing a bomb in a 
    prompted for row and column. Recursively continues until a valid row/column 
    of a piece is given.*)
let rec place_bomb state = 
  try 
    let row = 
      (read_line (print_endline 
                    "What row would you like to place the bomb in?")) in
    let col = 
      (read_line (print_endline 
                    "What column would you like to place the bomb in?")) in
    let result = 
      Game_mechanics.bomb state (int_of_string row) (int_of_string col) in
    match result with
    | Invalid -> raise InvalidPlacement
    | Valid new_state ->
      Display.print_start_turn new_state; 
      new_state
  with
  | Failure _ -> 
    print_endline "Non integer row and/or column provided. Please try again.";
    place_bomb state
  | InvalidPlacement ->
    print_endline "Invalid row and/or column provided. Please try again.";
    place_bomb state

(** [get_players ()] recursively asks for player to input the number of 
    players in their game until a valid number between [2,4] is given *)
(**update to allow for 1 player games *)
let rec get_players () = 
  let players = 
    (read_line (print_endline "\nHow many players? \n\
                               Choose a number between 2 and 4 inclusive.")) in
  match int_of_string_opt players with 
  | None -> Display.pretty_print_string "Please input a number."; get_players ()
  | Some p -> if p > 4 || p < 2
    then (Display.pretty_print_string "Invalid players number."; get_players () )
    else p

(** [get_rows ()] recursively asks for player to input a the number of rows
    they want for their board until a valid number between [4,10] is given *)
let rec get_rows () = 
  let rows = 
    (read_line (print_endline "\nHow many rows for your board? \n\
                               Choose a number between 4 and 10 inclusive.")) in
  match int_of_string_opt rows with 
  | None -> Display.pretty_print_string "Please input a number."; get_rows ()
  | Some r -> if r > 10 || r < 4
    then (Display.pretty_print_string "Invalid row number."; get_rows () )
    else r

(** [get_cols ()] recursively asks for player to input a the number of columns
    they want for their board until a valid number between [4,10] is given *)
let rec get_cols () = 
  let cols = 
    (read_line (print_endline "\nHow many columns for your board? \n\
                               Choose a number between 4 and 10 inclusive.")) in
  match int_of_string_opt cols with 
  | None -> Display.pretty_print_string "Please input a number."; get_cols ()
  | Some c -> if c > 10 || c < 4 
    then (Display.pretty_print_string "Invalid column number."; get_cols () )
    else c

(** [get_connect rows cols] recursively asks for player to input how 
    many pieces need to be connected to win the game until a valid number 
    between [3,6] is returned that isn't too big for the board size  *)
let rec get_connect rows cols = 
  let connect = 
    (read_line (print_endline "\nHow many pieces do you need to connect to win \
                               your game? \nChoose a number between 3 and 6 \
                               inclusive.")) in
  match int_of_string_opt connect with 
  | None -> Display.pretty_print_string "Please input a number."; 
    get_connect rows cols
  | Some c -> if c > 6 || c < 3 
    then (Display.pretty_print_string "Invalid connect number."; 
          get_connect rows cols ) 
    else if (c > rows && c > cols)
    then (Display.pretty_print_string "The board is too small for this. Please \
                                       pick another number"; 
          get_connect rows cols ) 
    else c

(** [get_colors player count acc] recursively asks for the player to input a 
    color for each player of the game and ensure no duplicate colors, returns
    a list of all the colors for each player in order *)
let rec get_colors players count acc = 
  if count = (players + 1) then List.rev acc else 
    let prompt = "\nPick a color for player " ^ (string_of_int count) ^ 
                 ".\nThe options are \"Red\", \"Green\", \"Yellow\", \"Blue\", \
                  \"Magenta\", or \"Cyan\"" in
    let color = (read_line (print_endline prompt)) in 
    let piece_color = 
      match color with 
      | "Red" -> if List.mem ANSITerminal.red acc 
        then (Display.pretty_print_string "Please input a different color.";
              ANSITerminal.black)
        else ANSITerminal.red
      | "Green" -> if List.mem ANSITerminal.green acc 
        then (Display.pretty_print_string "Please input a different color.";
              ANSITerminal.black)
        else ANSITerminal.green
      | "Yellow" -> if List.mem ANSITerminal.yellow acc 
        then (Display.pretty_print_string "Please input a different color.";
              ANSITerminal.black)
        else ANSITerminal.yellow
      | "Blue" -> if List.mem ANSITerminal.blue acc 
        then (Display.pretty_print_string "Please input a different color.";
              ANSITerminal.black)
        else ANSITerminal.blue
      | "Magenta" -> if List.mem ANSITerminal.magenta acc 
        then (Display.pretty_print_string "Please input a different color.";
              ANSITerminal.black)
        else ANSITerminal.magenta
      | "Cyan" -> if List.mem ANSITerminal.cyan acc 
        then (Display.pretty_print_string "Please input a different color.";
              ANSITerminal.black)
        else ANSITerminal.cyan
      | _ -> Display.pretty_print_string "Please input a valid color."; 
        ANSITerminal.black
    in if piece_color = ANSITerminal.black 
    then get_colors players count acc 
    else get_colors players (count + 1) (piece_color :: acc)

(** [get_game_mode ()] recursively asks for player to input a game mode
    until a valid mode 1,2 or 3 is given *)
let rec get_game_mode () = 
  let mode = 
    (read_line (print_endline "\nWhich game mode would you like to play? \n\
                               1 is no special pieces, 2 is 1 of each special \
                               piece, 3 is Random chance of receiving special \
                               pieces")) in
  match int_of_string_opt mode with 
  | None -> Display.pretty_print_string "Please input a number"; 
    get_game_mode ()
  | Some m -> if m > 3 || m < 1 
    then (Display.pretty_print_string "Invalid game mode"; get_game_mode() )
    else m

(** [special_game_setup ()] runs all the prompts for the user to adjust
    the settings for a custom game, then creates a custom game using 
    those settings *)
let special_game_setup () = 
  let players = get_players () in 
  let rows = get_rows () in 
  let cols = get_cols () in
  let connect_num = get_connect rows cols in
  let colors = get_colors players 1 [] in 
  let mode = get_game_mode () in
  start_custom_game rows cols players connect_num colors mode


(** [rec play_game state] recursively asks for player input one step at a time 
    and handles all possible commands after a game has been started. This 
    includes [help], [hand], [print], [save], [place] and [quit]. If a command 
    is empty or malformed, an explanation is printed and another command 
    is prompted for. *)
let rec play_game state = 
  let curr_player = Game_mechanics.get_player_turn state in
  let command = 
    (read_line (print_endline "Enter a command (type \"help\" if you need \
                               it)")) in
  try
    match Command.parse command with 
    | Command.Help ->
      Display.print_help ();
      play_game state
    | Command.Hand ->
      Display.print_hand state curr_player;
      play_game state
    | Command.Print ->
      Display.print_board state;
      play_game state
    | Command.Save object_phrase -> 
      let saved = save_handler state object_phrase in
      if not saved then play_game state else exit_game ()
    | Command.Place object_phrase ->
      let new_state = place_piece state object_phrase curr_player in
      Display.print_start_turn new_state;
      if Game_mechanics.is_bombed new_state then 
        play_game (place_bomb new_state) 
      else play_game new_state
    | Command.Quit ->
      Display.pretty_print_string "Ending the game and returning to the \
                                   game setup menu.";
      game_setup ()
    | _ -> raise Command.Malformed
  with
  | Command.Empty -> 
    Display.pretty_print_string "Empty command given. Please try again.";
    play_game state
  | Command.Malformed ->
    Display.pretty_print_string "Invalid command provided. Please try again.";
    play_game state

(** [game_setup ()] recursively asks for player input to either [start] the
    game, go to [settings] to create a custom game, [load] a game file and play, 
    or [exit] the game console. If a command is empty, malformed, or a
    failure, an explanation is printed and another command is prompted for. *)
and game_setup () = 
  let command = 
    (read_line (print_endline "Please type \"start\" to start a regular 2 \
                               player Connect 4 game, \"settings\" to create \
                               a custom Connect 4 game, \"load [filename]\" to \
                               load a previously saved game, or \"exit\" \
                               to exit the game console.")) in
  try
    match Command.parse command with 
    | Command.Start -> 
      let game_state = start_regular_game in
      Display.pretty_print_string "Game state started!";
      Display.print_start_turn game_state;
      play_game game_state
    | Command.Settings -> 
      let game_state = special_game_setup () in
      Display.pretty_print_string "Game state started!";
      Display.print_start_turn game_state;
      play_game game_state
    | Command.Load object_phrase -> 
      let game_state = load_handler object_phrase in
      Display.pretty_print_string "Game state loaded!";
      Display.print_start_turn game_state;
      play_game game_state
    | Command.Exit ->
      Display.pretty_print_string "Ok bye!";
      exit_game();
    | _ -> raise Command.Malformed
  with
  | Command.Empty -> 
    Display.pretty_print_string "Empty command given. Please try again.";
    game_setup ()
  | Command.Malformed -> 
    Display.pretty_print_string "Malformed command given. Please try again.";
    game_setup ()
  | Failure str -> 
    Display.pretty_print_string(String.concat "" 
                                  ["Game failed to load at file "; str; 
                                   ", please try again."]);
    game_setup ()

(** [main ()] prints a welcome message and runs the game setup. *)
let main () =
  ANSITerminal.(print_string [blue] "\nWelcome to Connect 4!\n");
  game_setup ()

(* Runs the game. *)
let () = main ()
