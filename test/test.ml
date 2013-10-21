
open OUnit2
open Sekred

let ignore_string : string -> unit = ignore

let test_simple = 
  "simple" >::
  (fun test_ctxt ->
     let tmpdn = bracket_tmpdir test_ctxt in
     let conf = {default_conf with vardir = tmpdn} in
     let () = init ~conf () in
     let t = create ~conf () in
    
     let string_list_printer = String.concat ", " in

(* TODO: fake uid.
     let () = 
       assert_equal
         ~msg:"No error in check."
         ~printer:string_list_printer
         []
         (check t)
     in
 *)

     let password1 = get t "foo" in
     let password2 = get t "foo" in
       assert_equal 
         ~msg:"Getting password twice."
         ~printer:(fun s -> s)
         password1 password2;
       assert_bool
         "Password not null."
         (String.length password1 > 0);

       assert_equal
         ~msg:"Step1: one entry."
         ~printer:string_list_printer
         ["foo"]
         (list t);

       (* Create a second entry. *)
       ignore_string (get t "bar");
       assert_equal
         ~msg:"Step2: two entries."
         ~printer:string_list_printer
         ["bar"; "foo"]
         (list t);

       (* Destroy an entry. *)
       delete t "bar";
       assert_equal
         ~msg:"Step3: back to one entry."
         ~printer:string_list_printer
         ["foo"]
         (list t);
  
       (* Set an entry. *)
       set t "bar" "thisisasecret";
       assert_equal
         ~msg:"Set works."
         ~printer:(fun s -> s)
         "thisisasecret"
         (get t "bar"))

let () = 
  run_test_tt_main
    ("Sekred" >:::
     [
       test_simple;
     ])
