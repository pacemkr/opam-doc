open Index
open Generate

let () = Printexc.record_backtrace true;;

let create_package_directory () =
  let package_name = Opam_doc_config.current_package () in
  if not Sys.(file_exists package_name && is_directory package_name) then
    Unix.mkdir package_name 0o755

let moduleName f =
  String.capitalize (Filename.chop_extension (Filename.basename f))

let pSameBase a =
  let open Filename in
  let base = chop_extension (basename a) in
    (fun b -> (chop_extension (basename b)) = base)

let filter_conflicts files =
  List.rev
    (List.fold_left
       (fun acc f ->
         if List.exists (pSameBase f) acc then begin
           Printf.eprintf "Duplicate module name: \"%s\"\n" (moduleName f);
           acc
         end else f :: acc) [] files)

let get_cmt cmd cmt_list =
  try
    Some (List.find (pSameBase cmd) cmt_list)
  with Not_found -> None

let process_cmd cmd =
  Cmd_format.(
    try
      let cmd = read_cmd cmd in Some cmd.cmd_doctree
    with
  _ -> None
  )

let copy_file input_name output_name =
  let open Unix in
  let buffer_size = 8192 in
  let buffer = String.create buffer_size in
  let fd_in = openfile input_name [O_RDONLY] 0 in
  let fd_out = openfile output_name [O_WRONLY; O_CREAT; O_TRUNC] 0o666 in
  let rec copy_loop () =
    match read fd_in buffer 0 buffer_size with
    | 0 -> ()
    | r -> ignore (write fd_out buffer 0 r);
           copy_loop ()
  in
    copy_loop ();
    close fd_in;
    close fd_out

let create_summary files =
  let filename =
    Opam_doc_config.current_package () ^ "/summary.html"
  in
    match Opam_doc_config.summary () with
      None -> Html_utils.generate_package_summary filename files
    | Some s ->
        if Sys.file_exists s then
          Unix.handle_unix_error (fun () -> copy_file s filename) ()
        else Printf.eprintf "Summary file %s does not exist\n" s

let create_index () =
  let filename =
    Opam_doc_config.current_package () ^ "/index.html"
  in
    Html_utils.generate_package_index filename

let rec check_package_name_conflict global =
  let rec loop () =
    begin
      Printf.printf "Package '%s' already exists. Proceed anyway? [Y/n/r] \n%!"
                    (Opam_doc_config.current_package ());
      Scanf.scanf "%c" (function
        | 'Y' | 'y' | '\n' -> ()
        | 'N' | 'n' -> Printf.printf "Conflict unresolved. Exiting now..."; exit 0
        | 'r' ->
      Printf.printf "New package name : ";
      Opam_doc_config.set_current_package (read_line ());
      check_package_name_conflict global
        | _ -> loop ())
    end
  in
  if Index.package_exists global (Opam_doc_config.current_package ())
     && not (Opam_doc_config.always_proceed ()) then loop ()

let process_file global cmd cmt =
  let module_name = moduleName cmd in
  let doctree = process_cmd cmd in
  let cmi, cmt = Cmt_format.read cmt in
  try
    match cmi, cmt with
      | _, None -> raise (Failure "Not a cmt file")
      | None, Some _ -> raise (Failure "I need the cmti")
      | Some cmi, Some cmt ->
        let imports = cmi.Cmi_format.cmi_crcs in
        let local = create_local global imports in
        (match doctree with
        | Some dt ->
              let filename = Opam_doc_config.current_package () ^ "/" ^  module_name ^ ".json" in
              let oc = open_out filename in
              output_string oc (Sexplib.Sexp.to_string_hum (Doctree.sexp_of_file dt));
              close_out oc
        | None -> ());
        Index.reset_internal_table ();
          match cmt.Cmt_format.cmt_annots with
            | Cmt_format.Interface intf ->
              Some (generate_file_from_interface local module_name doctree intf)
            | Cmt_format.Implementation impl ->
              Some (generate_file_from_structure local module_name doctree impl)
            | _ -> raise (Failure "Wrong kind of cmt file")
   with exn ->
     Printf.eprintf "Error while processing module %s: \"%s\"\n"
              module_name (Printexc.to_string exn);
     Printexc.print_backtrace stderr;
     None


let _ =
  let files = ref [] in

  Opam_doc_config.(
    Arg.parse options (fun file -> files := file :: !files) usage
  );

  (* read the saved global table *)
  let global = read_global_file (Opam_doc_config.index_file_path ()) in

  check_package_name_conflict global;

  let global = add_global_package global
    (Opam_doc_config.current_package ())
    (Opam_doc_config.package_descr ()) in
  let files = List.rev !files in

  let cmt_files = List.filter
    (fun file -> Filename.check_suffix file ".cmti"
      || Filename.check_suffix file ".cmt") files in

  let cmd_files = List.filter
    (fun file -> Filename.check_suffix file ".cmdi"
      || Filename.check_suffix file ".cmd") files in

  (* Remove the [ext] file when a [ext]i is found *)
  let filter_impl_files ext files =
    let exti = ext ^ "i" in
    let discard file =
      (Filename.check_suffix file ext)
      && (List.exists (fun filei ->
                       (Filename.check_suffix filei exti)
                       && (pSameBase file filei))
                      files)
    in
      List.filter (fun file -> not (discard file)) files
  in

  let cmt_files = filter_impl_files ".cmt" cmt_files in
  let cmd_files = filter_impl_files ".cmd" cmd_files in

  (* Update the global table with the future processed cmts *)
  let global = update_global global cmt_files in

  create_package_directory ();

  (* filter module name conflicts *)
  let cmt_files = filter_conflicts cmt_files in
  let cmd_files = filter_conflicts cmd_files in

  let processed_files =
    List.fold_left
      (fun l cmd ->
         match get_cmt cmd cmt_files with
         | Some cmt -> begin match process_file global cmd cmt with
           | Some o -> o :: l
           | None -> l
         end
         | None ->
           prerr_endline ("Warning: missing cmt file: " ^ cmd);
           l)
      []
      cmd_files
  in
  let processed_files =
    List.sort (fun (x,_) (y,_) -> compare x y) processed_files
  in

  if processed_files != [] then
    begin
      let open Html_utils in
    output_style_file ();
    output_script_file ();
          create_summary processed_files;
          create_index ();
    generate_global_packages_index global
    end;

  (* write down the updated global table *)
  write_global_file global (Opam_doc_config.index_file_path ())
