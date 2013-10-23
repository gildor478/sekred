
open OUnit2
open Sekred

let ignore_string : string -> unit = ignore

let string_list_printer = String.concat ", "

let assert_check conf =
  assert_equal
    ~msg:"No error in check."
    ~printer:string_list_printer
    []
    (check ~conf ())

let assert_equal_string_list ?msg a b =
  assert_equal ?msg ~printer:string_list_printer a b

let assert_equal_string ?msg a b =
  assert_equal ?msg ~printer:(fun s -> s) a b

let mock_conf test_ctxt =
  (* Temporary directory for vardir. *)
  let tmpdn = bracket_tmpdir test_ctxt in

  (* Fakeroot style mock. *)
  let self_uid, self_gid = Unix.getuid (), Unix.getgid () in
  let root_uid, root_gid = 0, 0 in
  let chown_db = Hashtbl.create 13 in
  let mock_chown fn uid gid =
    Hashtbl.replace chown_db fn (uid, gid)
  in
  let mock_stat fn =
    let st = Unix.stat fn in
    let maybe_fix real self root =
      if real = self then root else real
    in
    let fake_uid =
      try
        fst (Hashtbl.find chown_db fn)
      with Not_found ->
        maybe_fix st.Unix.st_uid self_uid root_uid
    in
    let fake_gid =
      try
        snd (Hashtbl.find chown_db fn)
      with Not_found ->
        maybe_fix st.Unix.st_gid self_gid root_gid
    in
      {st with Unix.st_uid = fake_uid; Unix.st_gid = fake_gid}
  in

    {
      default_conf with
          vardir = tmpdn;
          stat = mock_stat;
          chown = mock_chown
    }

let test_simple =
  "simple" >::
  (fun test_ctxt ->
     let conf = mock_conf test_ctxt in
     let () = init ~conf () in
     let t = create ~conf () in

       assert_bool "User not enabled." (not (is_enabled t));
       enable t;
       assert_bool "User enabled." (is_enabled t);
       assert_check conf;

       assert_check conf;
       assert_equal_string
         ~msg:"Getting password twice."
         (get t "foo") (get t "foo");
       assert_bool
         "Password not null."
         (String.length (get t "foo") > 0);

       assert_equal_string_list
         ~msg:"Step1: one entry."
         ["foo"] (list t);

       (* Create a second entry. *)
       ignore_string (get t "bar");
       assert_check conf;
       assert_equal_string_list
         ~msg:"Step2: two entries."
         ["bar"; "foo"] (list t);

       (* Destroy an entry. *)
       delete t "bar";
       assert_check conf;
       assert_equal_string_list
         ~msg:"Step3: back to one entry."
         ["foo"] (list t);

       (* Set an entry. *)
       set t "bar" "thisisasecret";
       assert_check conf;
       assert_equal_string
         ~msg:"Set works."
         "thisisasecret" (get t "bar");

       assert_bool "User enabled." (is_enabled t);
       disable t;
       assert_bool "User disabled." (not (is_enabled t));
       assert_check conf)

let test_upgrade =
  "upgrade" >::
  (fun test_ctxt ->
     let conf = mock_conf test_ctxt in
     let domainsdir = Filename.concat conf.vardir "domains" in
     let mkdomain bn owner content =
       let fn = Filename.concat domainsdir bn in
       let chn_out = open_out fn in
         output_string chn_out content;
         close_out chn_out;
         conf.chown fn owner (conf.stat fn).Unix.st_gid;
         conf.chmod fn 0o600
     in
     let domain1, pw1, uid1 = "foo", "foo++", 1001 in
     let domain2, pw2, uid2 = "bar", "++bar", 1002 in

     let () =
       (* Create a v0.1 installation. *)
       Unix.mkdir domainsdir 0o755;
       conf.chmod domainsdir 0o1770;
       mkdomain domain1 uid1 pw1;
       mkdomain domain2 uid2 pw2
     in
       assert_bool
         "Errors exist."
         (check ~conf () <> []);

       init ~conf ();
       assert_check conf;

       assert_equal_string
         ~msg:"Get back passwd1"
         pw1
         (get (create ~conf ~uid:uid1 ()) domain1);

       assert_equal_string
         ~msg:"Get back passwd2"
         pw2
         (get (create ~conf ~uid:uid2 ()) domain2))

let () =
  run_test_tt_main
    ("Sekred" >:::
     [
       test_simple;
       test_upgrade;
     ])
