structure SharingTables :> SharingTables =
struct

open Term Type

structure Map = Binarymap

(* ----------------------------------------------------------------------
    IDs (also known as Theory-X pairs, where X is a Name for a constant,
    or Tyops for types)
   ---------------------------------------------------------------------- *)

type id = {Thy : string, Other : string}
type idtable = {idsize : int,
                idmap : (id, int) Map.dict,
                idlist : id list}

fun make_shared_id (id : id) idtable =
    case Map.peek(#idmap idtable, id) of
      SOME i => (i, idtable)
    | NONE => let
        val {idsize, idmap, idlist} = idtable
      in
        (idsize, {idsize = idsize + 1,
                  idmap = Map.insert(idmap, id, idsize),
                  idlist = id :: idlist})
      end
fun id_compare ({Other = id1, Thy = thy1}, {Other = id2, Thy = thy2}) =
    case String.compare(id1, id2) of
      EQUAL => String.compare(thy1, thy2)
    | x => x


val empty_idtable : idtable = {idsize = 0,
                               idmap = Map.mkDict id_compare,
                               idlist = []}


val CB = PP.block PP.CONSISTENT 0
val out = PP.add_string
val NL = PP.NL

fun output_idtable name (idtable : idtable) = let
  val idlist = List.rev (#idlist idtable)
  fun print_id {Thy, Other} =
    out ("ID(" ^ Lib.mlquote Thy^ ", "^Lib.mlquote Other^")")
  val print_ids = PP.pr_list print_id [PP.add_break(1,0)]
in
  CB [
    out ("val "^name^" = "), NL,
    out ("  let fun ID(thy,oth) = {Thy = thy, Other = oth}"), NL,
    out ("  in Vector.fromList"), NL,
    out ("["),
    PP.block PP.INCONSISTENT 0 (print_ids idlist),
    out "]", NL,
    out "end;", NL
  ]
end

fun theoryout_idtable (idtable : idtable) = let
  val idlist = List.rev (#idlist idtable)
  fun print_id {Thy, Other} = out (Lib.mlquote Thy^ " " ^ Lib.mlquote Other)
  val print_ids = PP.pr_list print_id [PP.add_string ",", PP.add_break(1,0)]
in
  CB [out "[",
      PP.block PP.INCONSISTENT 1 (print_ids idlist),
      out "]"
  ]
end

(* ----------------------------------------------------------------------
    Types
   ---------------------------------------------------------------------- *)

datatype shared_type = TYV of string
                     | TYOP of int list

type typetable = {tysize : int,
                  tymap : (hol_type, int)Map.dict,
                  tylist : shared_type list}

fun make_shared_type ty idtable table =
    case Map.peek(#tymap table, ty) of
      SOME i => (i, idtable, table)
    | NONE => let
      in
        if is_vartype ty then let
            val {tysize, tymap, tylist} = table
          in
            (tysize, idtable,
             {tysize = tysize + 1,
              tymap = Map.insert(tymap, ty, tysize),
              tylist = TYV (dest_vartype ty) :: tylist})
          end
        else let
            val {Thy, Tyop, Args} = dest_thy_type ty
            val (id, idtable0) =
                make_shared_id {Thy = Thy, Other = Tyop} idtable
            fun foldthis (tyarg, (results, idtable, table)) = let
              val (result, idtable', table') =
                  make_shared_type tyarg idtable table
            in
              (result::results, idtable', table')
            end
            val (newargs, idtable', table') =
                List.foldr foldthis ([], idtable0, table) Args
            val {tysize, tymap, tylist} = table'
          in
            (tysize, idtable',
             {tysize = tysize + 1,
              tymap = Map.insert(tymap, ty, tysize),
              tylist = TYOP (id :: newargs) :: tylist})
          end
      end

val empty_tytable : typetable =
    {tysize = 0, tymap = Map.mkDict Type.compare, tylist = [] }

fun build_type_vector idv shtylist = let
  fun build1 (shty, (n, tymap)) =
      case shty of
        TYV s => (n + 1, Map.insert(tymap, n, Type.mk_vartype s))
      | TYOP idargs => let
          val (id, Args) = valOf (List.getItem idargs)
          val args = map (fn i => Map.find(tymap, i)) Args
          val {Thy,Other} = Vector.sub(idv, id)
        in
          (n + 1,
           Map.insert(tymap, n,
                            Type.mk_thy_type {Thy = Thy, Tyop = Other,
                                              Args = args}))
        end
  val (_, tymap) =
      List.foldl build1 (0, Map.mkDict Int.compare) shtylist
in
  Vector.fromList (map #2 (Map.listItems tymap))
end

fun output_typetable {idtable_nm,tytable_nm} (tytable : typetable) = let
  fun output_shtype shty =
      case shty of
        TYV s => out ("TYV "^Lib.mlquote s)
      | TYOP args =>
        out ("TYOP ["^
             String.concat (Lib.commafy (map Int.toString args))^ "]")
  val output_shtypes = PP.pr_list output_shtype [out ",", PP.add_break (1,0)]
in
  CB [
    out "local open SharingTables", NL, out "in", NL,
    out ("val "^tytable_nm^" = build_type_vector "^idtable_nm), NL,
    out ("["),
    PP.block PP.INCONSISTENT 0 (output_shtypes (List.rev (#tylist tytable))),
    out "]", NL, out "end", NL
  ]
end

fun theoryout_typetable (tytable : typetable) = let
  fun output_shtype shty =
      case shty of
        TYV s => out ("TYV "^ Lib.mlquote s)
      | TYOP args =>
        out ("TYOP "^ String.concatWith " " (map Int.toString args))
  val output_shtypes = PP.pr_list output_shtype [out ",", PP.add_break (1,0)]
in
  CB [
    out "[",
    PP.block PP.INCONSISTENT 1 (output_shtypes (List.rev (#tylist tytable))),
    out "]"
  ]
end


(* ----------------------------------------------------------------------
    Terms
   ---------------------------------------------------------------------- *)

datatype shared_term = TMV of string * int
                     | TMC of int * int
                     | TMAp of int * int
                     | TMAbs of int * int

type termtable = {termsize : int,
                  termmap : (term, int)Map.dict,
                  termlist : shared_term list}

val empty_termtable : termtable =
    {termsize = 0, termmap = Map.mkDict Term.compare, termlist = [] }

fun make_shared_term tm (tables as (idtable,tytable,tmtable)) =
    case Map.peek(#termmap tmtable, tm) of
      SOME i => (i, tables)
    | NONE => let
      in
        if is_var tm then let
            val (s, ty) = dest_var tm
            val (ty_i, idtable, tytable) =
                make_shared_type ty idtable tytable
            val {termsize, termmap, termlist} = tmtable
          in
            (termsize,
             (idtable, tytable,
              {termsize = termsize + 1,
               termmap = Map.insert(termmap, tm, termsize),
               termlist = TMV (s, ty_i) :: termlist}))
          end
        else if is_const tm then let
            val {Thy,Name,Ty} = dest_thy_const tm
            val (id_i, idtable) =
                make_shared_id {Thy = Thy, Other = Name} idtable
            val (ty_i, idtable, tytable) =
                make_shared_type Ty idtable tytable
            val {termsize, termmap, termlist} = tmtable
          in
            (termsize,
             (idtable, tytable,
              {termsize = termsize + 1,
               termmap = Map.insert(termmap, tm, termsize),
               termlist = TMC (id_i, ty_i) :: termlist}))
          end
        else if is_comb tm then let
            val (f, x) = dest_comb tm
            val (f_i, tables) = make_shared_term f tables
            val (x_i, tables) = make_shared_term x tables
            val (idtable, tytable, tmtable) = tables
            val {termsize, termmap, termlist} = tmtable
          in
            (termsize,
             (idtable, tytable,
              {termsize = termsize + 1,
               termmap = Map.insert(termmap, tm, termsize),
               termlist = TMAp(f_i, x_i) :: termlist}))
          end
        else  (* must be an abstraction *) let
            val (v, body) = dest_abs tm
            val (v_i, tables) = make_shared_term v tables
            val (body_i, tables) = make_shared_term body tables
            val (idtable, tytable, tmtable) = tables
            val {termsize, termmap, termlist} = tmtable
          in
            (termsize,
             (idtable, tytable,
              {termsize = termsize + 1,
               termmap = Map.insert(termmap, tm, termsize),
               termlist = TMAbs(v_i, body_i) :: termlist}))
          end
      end

fun build_term_vector idv tyv shtmlist = let
  fun build1 (shtm, (n, tmmap)) =
      case shtm of
        TMV (s, tyn) => (n + 1,
                         Map.insert(tmmap, n, mk_var(s, Vector.sub(tyv, tyn))))
      | TMC (idn, tyn) => let
          val {Thy, Other} = Vector.sub(idv, idn)
          val ty = Vector.sub(tyv, tyn)
        in
          (n + 1, Map.insert(tmmap, n, mk_thy_const {Name = Other, Thy = Thy,
                                                     Ty = ty}))
        end
      | TMAp (f_n, xn) =>
        (n + 1, Map.insert(tmmap, n, mk_comb(Map.find(tmmap, f_n),
                                             Map.find(tmmap, xn))))
      | TMAbs (vn, bodyn) =>
        (n + 1, Map.insert(tmmap, n, mk_abs(Map.find(tmmap, vn),
                                            Map.find(tmmap, bodyn))))
  val (_, tmmap) = List.foldl build1 (0, Map.mkDict Int.compare) shtmlist
in
  Vector.fromList (map #2 (Map.listItems tmmap))
end

fun output_termtable names (tmtable: termtable) = let
  val {idtable_nm,tytable_nm,termtable_nm} = names
  fun ipair_string (x,y) = "("^Int.toString x^", "^Int.toString y^")"
  fun output_shtm shtm =
    case shtm of
        TMV (s, tyn) => out ("TMV(" ^ Lib.mlquote s ^", "^Int.toString tyn^")")
      | TMC p => out ("TMC"^ipair_string p)
      | TMAp p => out ("TMAp"^ipair_string p)
      | TMAbs p => out ("TMAbs"^ipair_string p)
  val output_shtms = PP.pr_list output_shtm [out ",", PP.add_break(1,0)]
in
  CB [
    out ("local open SharingTables"), NL,
    out ("in"), NL,
    out ("val "^termtable_nm^" = build_term_vector "^idtable_nm^" "^
         tytable_nm), NL,
    out ("["),
    PP.block PP.INCONSISTENT 0 (output_shtms (List.rev (#termlist tmtable))),
    out ("]"), NL,
    out "end", NL
  ]
end;

fun theoryout_termtable (tmtable: termtable) =
  let
    fun ipair_string (x,y) = Int.toString x^" "^Int.toString y
    fun output_shtm shtm =
      case shtm of
          TMV (s, tyn) =>
            out ("TMV " ^ Lib.mlquote s ^" "^Int.toString tyn)
        | TMC p => out ("TMC "^ipair_string p)
        | TMAp p => out ("TMAp "^ipair_string p)
        | TMAbs p => out ("TMAbs "^ipair_string p)
    val output_shtms = PP.pr_list output_shtm [out ",", PP.add_break(1,0)]
  in
    CB [
      out ("["),
      PP.block PP.INCONSISTENT 1 (output_shtms (List.rev (#termlist tmtable))),
      out ("]")
    ]
  end

end; (* struct *)
