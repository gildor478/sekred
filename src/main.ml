type action_t = 
  | Get of string
  | Delete of string
  | Set of string * string
  | Check 
  | Init
  | List 

let () = 
  let faction = 
    ref (fun () -> List)
  in
  let domain =
    ref (fun () -> 
           failwith "You need to set --domain=... for this action.")
  in
  let password = 
    ref (fun () ->
           failwith "You need to set --password=... for this action.")
  in
  let vardir =
    ref None
  in
  let args = 
    [
      "--vardir",
      Arg.String
        (fun fn -> vardir := Some fn),
      "fn Set sekred vardir.";

      "--domain",
      Arg.String 
        (fun str ->
           domain := fun () -> str),
      "str Domain to consider for the action.";

      "--password",
      Arg.String
        (fun str ->
           password := fun () -> str),
      "str Password to set.";

      "--password_fn",
      Arg.String
        (fun fn ->
           let chn = open_in fn in
           let str = input_line chn in
             close_in chn;
             password := fun () -> str),
      "fn Read password from file.";

      "--get",
      Arg.Unit 
        (fun () ->
           faction := (fun () -> Get (!domain ()))),
      " Get a password for a given domain.";

      "--delete",
      Arg.Unit 
        (fun () ->
           faction := (fun () -> Delete (!domain ()))),
      " Delete a domain.";

      "--set",
      Arg.Unit
        (fun () ->
           faction := (fun () -> Set (!domain (), !password ()))),
      " Set a password for a domain.";

      "--list",
      Arg.Unit
        (fun () ->
           faction := (fun () -> List)),
      " List accessible domains.";


      "--check",
      Arg.Unit
        (fun () ->
           faction := (fun () -> Check)),
      " Check installation.";

      "--init",
      Arg.Unit
        (fun () ->
           faction := (fun () -> Init)),
      " Initialize installation.";
    ]
  in
  let () = 
    Arg.parse
      (Arg.align args)
      (fun str -> failwith (Printf.sprintf "Don't know what to do with '%s'."  str))
      (Printf.sprintf "sekred v%s\n\nOptions:\n" SekredConf.version)
  in
  let vardir = !vardir in
  let action = !faction () in
  let t () = Sekred.create ?vardir () in (* TODO: uid *)
    match action with 
      | Get domain ->
          print_endline (Sekred.get (t ()) domain)
      | Delete domain ->
          Sekred.delete (t ()) domain
      | Set (domain, password) ->
          Sekred.set (t ()) domain password
      | List ->
          List.iter print_endline (Sekred.list (t ()))
      | Check ->
          let lst = Sekred.check (t ()) in
            if lst <> [] then
              begin
                List.iter prerr_endline lst;
                exit 1
              end
      | Init ->
          Sekred.init ?vardir ()



