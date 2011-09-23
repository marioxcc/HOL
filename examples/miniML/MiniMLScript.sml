(* generated by Lem from miniML.lem *)
open bossLib Theory Parse res_quanTheory
open finite_mapTheory listTheory pairTheory pred_setTheory
open set_relationTheory sortingTheory stringTheory wordsTheory

val _ = new_theory "MiniML"

(* By Scott Owens, University of Cambridge, Copyright 2011
 *
 * Miniml is my idea of the simplest ML-like language that remains convenient
 * to program in.  It is purely functional (no refs or exceptions), has no
 * modules, no type abbreviations, or record types.  It does have mutually
 * recursive datatypes (at the top-level only) and functions, as well as
 * higher-order functions.  It also supports pattern matching for nested
 * patterns (which can fail due to non-exhaustive patterns).  Only booleans and
 * number types are built-in.  Syntactic sugar is generally omitted.
 *
 * In some ways it makes more sense to write these kind of semantics in Ott (to
 * get a presentation that looks like ML concrete-syntax-wise, and that has the
 * usual syntax for type systems and operational semantics, i.e., with |- and
 * horizontal lines).  Here in Lem, everything looks like abstract syntax;
 * however, unlike Ott, we get good support for functions, and not just
 * relations.
 * 
 * The small-step operational semantics is based on the CEK machine.  The type
 * system is typical, but it doesn't yet support polymorphism.  The big step
 * semantics is also typical.  The small-step and big-step semantics agree even
 * on untyped programs. *)

(*val all_distinct : forall 'a. 'a list -> bool*)

(*val rtc : forall 'a. ('a -> 'a -> bool) -> ('a -> 'a -> bool)*)

(* Environments *)
val _ = type_abbrev((*  ('a,'b) *) "env" , ``: ('a#'b) list``);

(*val emp : forall 'a 'b. ('a,'b) env*)
val _ = Define `
 emp = []`;


(*val lookup : forall 'a 'b. 'a -> ('a,'b) env -> 'b option*)
 val lookup_defn = Hol_defn "lookup" `
 
(lookup n [] = NONE)
/\
(lookup n ((n',v)::e) =
  if n' = n then
    SOME v
  else
    lookup n e)`;

val _ = Defn.save_defn lookup_defn; 

(*val bind : forall 'a 'b. 'a -> 'b -> ('a,'b) env -> ('a,'b) env*)
val _ = Define `
 (bind n v e = (n,v)::e)`;


(*val merge : forall 'a 'b. ('a,'b) env -> ('a,'b) env -> ('a,'b) env*)
val _ = Define `
 (merge e1 e2 = e1 ++ e2)`;


(* Literal constants *)
val _ = Hol_datatype `
 lit = 
    Num of num
  | Bool of bool`;


(* Built-in binary operations (including function application) *)
val _ = Hol_datatype `
 op =
    (* e.g. + - * / *)
    Opn of (num -> num -> num)
    (* e.g.  < > <= >= *)
  | Opb of (num -> num -> bool)
  | Opapp`;


(* Built-in logical operations *)
val _ = Hol_datatype `
 log = 
    And
  | Or`;
 

(* Variable names *)
val _ = type_abbrev( "varN" , ``: string``);
(* Constructor names (from datatype definitions) *)
val _ = type_abbrev( "conN" , ``: string``);
(* Type names *)
val _ = type_abbrev( "typeN" , ``: string``);
(* Type variable names *)
val _ = type_abbrev( "tvarN" , ``: string``);

(* Types
 * 0-ary type applications represent unparameterised types (e.g., num or string)
 *)
val _ = Hol_datatype `
 t = 
    Tvar of tvarN
  | Tapp of t list => typeN
  | Tfn of t => t
  | Tnum
  | Tbool`;


(* Simultaneous substitution of types for type variables in a type *)
(*val type_subst : (tvarN,t) env -> t -> t*)
 val type_subst_defn = Hol_defn "type_subst" `

(type_subst s (Tvar tv) =
  (case lookup tv s of
       NONE -> Tvar tv
    || SOME(t) -> t
  )) 
/\
(type_subst s (Tapp ts tn) =
  Tapp (MAP (type_subst s) ts) tn)
/\
(type_subst s (Tfn t1 t2) =
  Tfn (type_subst s t1) (type_subst s t2))
/\
(type_subst s Tnum = Tnum)
/\
(type_subst s Tbool = Tbool)`;

val _ = Defn.save_defn type_subst_defn;

(* Check that the free type variables are in the given list *)
(*val check_freevars : tvarN list -> t -> bool*)
 val check_freevars_defn = Hol_defn "check_freevars" `

(check_freevars tvs (Tvar tv) =
  MEM tv tvs)
/\
(check_freevars tvs (Tapp ts tn) =
  EVERY (check_freevars tvs) ts)
/\
(check_freevars tvs (Tfn t1 t2) =
  check_freevars tvs t1 /\ check_freevars tvs t2)
/\
(check_freevars tvs Tnum = T)
/\
(check_freevars tvs Tbool = T)`;

val _ = Defn.save_defn check_freevars_defn;

(* Patterns *)
val _ = Hol_datatype `
 pat =
    Pvar of varN
  | Plit of lit
  (* Constructor applications *)
  | Pcon of conN => pat list`;


(* Runtime errors *)
val _ = Hol_datatype `
 error = 
    Bind_error`;


(* Expressions *)
val _ = Hol_datatype `
 exp = 
    Raise of error
  | Val of v
  (* Constructor application *)
  | Con of conN => exp list
  | Var of varN
  | Fun of varN => exp
  (* Application of an operator (including function application) *)
  | App of op => exp => exp
  (* Logical operations (and, or) *)
  | Log of log => exp => exp
  | If of exp => exp => exp
  (* Pattern matching *)
  | Mat of exp => (pat # exp) list
  | Let of varN => exp => exp
  (* Local definition of (potentially) mutually recursive functions 
   * The first varN is the function's name, and the second varN is its
   * parameter *)
  | Letrec of (varN # varN # exp) list => exp

(* Value forms *)
; v =
    Lit of lit
  (* Constructor application *)
  | Conv of conN => v list
  (* Function closures
     The environment is used for the free variables in the function *)
  | Closure of (varN, v) env => varN => exp
  (* Function closure for recursive functions 
   * See Closure and Letrec above
   * The last variable name indicates which function from the mutually
   * recursive bundle this closure value represents *) 
  | Recclosure of (varN, v) env => (varN # varN # exp) list => varN`;


(* Environments *)
val _ = type_abbrev( "envE" , ``: (varN, v) env``);

(* Declarations *)
val _ = Hol_datatype `
 dec = 
  (* Top-level bindings
     The pattern allows several names to be bound at once *)
    Dlet of pat => exp
  (* Mutually recursive function definition *)
  | Dletrec of (varN # varN # exp) list  
  (* Type definition
     Defines several types, each of which has several named variants, which can
     in turn have several arguments *)
  | Dtype of (tvarN list # typeN # (conN # t list) list) list`;


val _ = type_abbrev( "decs" , ``: dec list``);

(* Maps each constructor to its arity and the set of all constructors of that
 * type *) 
val _ = type_abbrev( "envC" , ``: (conN, num # conN set) env``);

(* Evaluation contexts 
 * The hole is denoted by the unit type 
 * The env argument contins bindings for the free variables of expressions in
     the context *)
val _ = Hol_datatype `
 ctxt_frame = 
    Capp1 of op => unit => exp
  | Capp2 of op => v => unit
  | Clog of log => unit => exp
  | Cif of unit => exp => exp
  | Cmat of unit => (pat # exp) list
  | Clet of varN => unit => exp
  (* Evaluating a constructor's arguments
   * The v list should be in reverse order. *)
  | Ccon of conN => v list => unit => exp list`;

val _ = type_abbrev( "ctxt" , ``: ctxt_frame # envE``);

(*val lit_same_type : lit -> lit -> bool*)
val _ = Define `
 (lit_same_type l1 l2 =
  (case (l1,l2) of
       (Num _, Num _) -> T
    || (Bool _, Bool _) -> T
    || _ -> F
  ))`;


val _ = Hol_datatype `
 match_result =
    No_match
  | Match_type_error
  | Match of envE`;


(* A big-step pattern matcher.  If the value
 * matches the pattern, return an environment with the pattern variables bound
 * to the corresponding sub-terms of the value; this environment extends the
 * environment given as an argument.  No_match is returned when there is no
 * match, but any constructors encountered in determining the match failure are
 * applied to the correct number of arguments, and constructors in
 * corresponding positions in the pattern and value come from the same type.
 * Match_type_error is returned when one of these conditions is violated *)

(*val pmatch : envC -> pat -> v -> envE -> match_result*)
 val pmatch_defn = Hol_defn "pmatch" `
 
(pmatch envC (Pvar n) v' env = Match (bind n v' env))
/\
(pmatch envC (Plit l) (Lit l') env =
  if l = l' then
    Match env
  else if lit_same_type l l' then
    No_match
  else
    Match_type_error)
/\
(pmatch envC (Pcon n ps) (Conv n' vs) env =
  (case (lookup n envC, lookup n' envC) of
       (SOME (l, ns), SOME (l', ns')) ->
        if n IN ns' /\ n' IN ns /\ (LENGTH ps = l) /\ (LENGTH vs = l')
        then
          if n = n' then
            pmatch_list envC ps vs env
          else
            No_match
        else
          Match_type_error
    || (_, _) -> Match_type_error
  ))
/\
(pmatch envC _ _ env = Match_type_error)
/\
(pmatch_list envC [] [] env = Match env)
/\
(pmatch_list envC (p::ps) (v::vs) env =
  (case pmatch envC p v env of
       No_match -> No_match
    || Match_type_error -> Match_type_error
    || Match env' -> pmatch_list envC ps vs env'
  ))
/\
(pmatch_list envC _ _ env = Match_type_error)`;

val _ = Defn.save_defn pmatch_defn;

(* State for CEK-style expression evaluation
 * - constructor data
 * - the environment for the free variables of the current expression 
 * - the current expression to evaluate
 * - the context stack (continuation) of what to do once the current expression
 *   is finished.  Each entry has an environment for it's free variables *)
val _ = type_abbrev( "state" , ``: envC # envE # exp # ctxt list``);

val _ = Hol_datatype `
 e_step_result =
    Estep of state
  | Etype_error
  | Estuck`;


(* The semantics are deterministic, and presented functionally instead of
 * relationally for proof rather that readability; the steps are very small: we
 * push individual frames onto the context stack instead of finding a redex in a
 * single step *)

(*val push : envC -> envE -> exp -> ctxt_frame -> ctxt list -> e_step_result*)
val _ = Define `
 (push envC env e c' cs = Estep (envC, env, e, (c',env)::cs))`;


(*val return : envC -> envE -> v -> ctxt list -> e_step_result*)
val _ = Define `
 (return envC env v c = Estep (envC, env, Val v, c))`;


(* Bind each function of a mutually recursive set of functions to its closure *)
(*val build_rec_env : (varN * varN * exp) list -> envE -> envE*)
 val build_rec_env_defn = Hol_defn "build_rec_env" `
 (build_rec_env funs env =
  FOLDR 
    (\ (f,x,e) env' . bind f (Recclosure env funs f) env') 
    env 
    funs)`;

val _ = Defn.save_defn build_rec_env_defn;

(* Lookup in the list of mutually recursive functions *)
(*val find_recfun : varN -> (varN * varN * exp) list -> (varN * exp)option*)
 val find_recfun_defn = Hol_defn "find_recfun" `
 (find_recfun n funs =
  (case funs of
       [] -> NONE
    || (f,x,e) :: funs -> 
        if f = n then 
          SOME (x,e)
        else 
          find_recfun n funs
  ))`;

val _ = Defn.save_defn find_recfun_defn;

(* Do an application *)
(*val do_app : envE -> op -> v -> v -> (envE * exp)option*)
val _ = Define `
 (do_app env' op v1 v2 =
  (case (op, v1, v2) of
       (Opapp, Closure env n e, v) ->
        SOME (bind n v env, e)
    || (Opapp, Recclosure env funs n, v) ->
        (case find_recfun n funs of
             SOME (n,e) -> SOME (bind n v (build_rec_env funs env), e)
          || NONE -> NONE
        )
    || (Opn op, Lit (Num n1), Lit (Num n2)) -> 
        SOME (env',Val (Lit (Num (op n1 n2))))
    || (Opb op, Lit (Num n1), Lit (Num n2)) -> 
        SOME (env',Val (Lit (Bool (op n1 n2)))) 
    || _ -> NONE
  ))`;


(* Do a logical operation *)
(*val do_log : log -> v -> exp -> exp option*)
val _ = Define `
 (do_log l v e =
  (case (l, v) of
       (And, Lit (Bool T)) -> SOME e
    || (Or, Lit (Bool F)) -> SOME e
    || (_, Lit (Bool _)) -> SOME (Val v)
    || _ -> NONE
  ))`;


(* Do an if-then-else *)
(*val do_if : v -> exp -> exp -> exp option*)
val _ = Define `
 (do_if v e1 e2 =
  if v = Lit (Bool T) then
    SOME e1
  else if v = Lit (Bool F) then
    SOME e2
  else
    NONE)`;


(* Check that a constructor is properly applied *)
(*val do_con_check : envC -> conN -> num -> bool*)
val _ = Define `
 (do_con_check envC n l =
  (case lookup n envC of
       NONE -> F
    || SOME (l',ns) -> l = l' 
  ))`;


(* apply a context to a value *)
(*val continue : envC -> v -> ctxt list -> e_step_result*)
val _ = Define `
 (continue envC v cs =
  (case cs of
       [] -> Estuck
    || (Capp1 op () e, env) :: c -> 
        push envC env e (Capp2 op v ()) c
    || (Capp2 op v' (), env) :: c ->
        (case do_app env op v' v of
             SOME (env,e) -> Estep (envC, env, e, c)
          || NONE -> Etype_error
        )
    || (Clog l () e, env) :: c ->
        (case do_log l v e of
             SOME e -> Estep (envC, env, e, c)
          || NONE -> Etype_error
        )
    || (Cif () e1 e2, env) :: c ->
        (case do_if v e1 e2 of
             SOME e -> Estep (envC, env, e, c)
          || NONE -> Etype_error
        )
    || (Cmat () [], env) :: c ->
        Estep (envC, env, Raise Bind_error, c)
    || (Cmat () ((p,e)::pes), env) :: c ->
        (case pmatch envC p v env of
             Match_type_error -> Etype_error
          || No_match -> push envC env (Val v) (Cmat () pes) c
          || Match env' -> Estep (envC, env', e, c)
        )
    || (Clet n () e, env) :: c ->
        Estep (envC, bind n v env, e, c) 
    || (Ccon n vs () [], env) :: c ->
        if do_con_check envC n (LENGTH vs + 1) then
          return envC env (Conv n (REVERSE (v::vs))) c
        else
          Etype_error
    || (Ccon n vs () (e::es), env) :: c ->
        if do_con_check envC n (LENGTH vs + 1 + 1 + LENGTH es) then
          push envC env e (Ccon n (v::vs) () es) c
        else
          Etype_error
  ))`;


(* The single step expression evaluator.  Returns None if there is nothing to
 * do, but no type error.  Returns Type_error on encountering free variables,
 * mis-applied (or non-existent) constructors, and when the wrong kind of value
 * if given to a primitive.  Returns Bind_error when no pattern in a match
 * matches the value.  Otherwise it returns the next state *)

(*val e_step : state -> e_step_result*)
val _ = Define `
 (e_step (envC, env, e, c) =
  (case e of
       Raise e -> 
        (case c of
             [] -> Estuck
          || _::c -> Estep (envC,env,Raise e,c)
        )
    || Val v  -> 
	continue envC v c
    || Con n es -> 
        if do_con_check envC n (LENGTH es) then
          (case es of
               [] -> return envC env (Conv n []) c
            || e::es ->
                push envC env e (Ccon n [] () es) c
          )
        else
          Etype_error
    || Var n ->
        (case lookup n env of
             NONE -> Etype_error
          || SOME v -> return envC env v c
        )
    || Fun n e -> return envC env (Closure env n e) c
    || App op e1 e2 -> push envC env e1 (Capp1 op () e2) c 
    || Log l e1 e2 -> push envC env e1 (Clog l () e2) c
    || If e1 e2 e3 -> push envC env e1 (Cif () e2 e3) c
    || Mat e pes -> push envC env e (Cmat () pes) c
    || Let n e1 e2 -> push envC env e1 (Clet n () e2) c
    || Letrec funs e ->
        if ~ (ALL_DISTINCT (MAP (\ (x,y,z) . x) funs)) then
          Etype_error
        else
          Estep (envC, build_rec_env funs env, e, c)
  ))`;
 

(* Add the given type definition to the given constructor environment *)
(*val build_tdefs : 
  (tvarN list * typeN * (conN * t list) list) list -> envC -> envC*)
val _ = Define `
 (build_tdefs tds envC =
  FOLDR 
    (\ (tvs, tn, condefs) envC .
       FOLDR 
         (\ (conN, ts) envC .
            bind conN (LENGTH ts, 
                       {cn | cn,ts | ( MEM(cn,ts) condefs) /\ T}) envC) 
         envC 
         condefs) 
    envC 
    tds)`;
 

(* Checks that no constructor is defined twice *)
(*val check_dup_ctors : 
    forall 'a. (tvarN list * typeN * (conN * t list) list) list -> (conN,'a) env -> bool*)
val _ = Define `
 (check_dup_ctors tds envC =
  (! ((tvs, tn, condefs) :: LIST_TO_SET tds) ((n, ts) :: LIST_TO_SET condefs).
   lookup n envC = NONE) /\
  ALL_DISTINCT 
    (let x2 = [] in FOLDR  (\(tvs, tn, condefs) x2 . FOLDR  (\(n, ts) x2 . if T then n:: x2 else x2)  x2  condefs)  x2  tds))`;


(* Whole program state
 * - constructor data
 * - values bound be previous definitions
 * - remaining definitions
 * - current state for evaluating the current definition *)
val _ = type_abbrev( "d_state" , ``: envC # envE # decs # (pat # state)option``);

val _ = Hol_datatype `
 d_step_result =
    Dstep of d_state
  | Draise of error
  | Dtype_error
  | Dstuck`;


(*val d_step : d_state -> d_step_result*)
val _ = Define `
 (d_step (envC, env, ds, st) =
  (case st of
       SOME (p, (envC', env', Val v, [])) -> 
        (case pmatch envC p v env of
             Match env' -> Dstep (envC, env', ds, NONE)
          || No_match -> Draise Bind_error
          || Match_type_error -> Dtype_error
        )
    || SOME (p, (envC, env', Raise err, [])) ->
        Draise err
    || SOME (p, (envC', env', e, c)) -> 
        (case e_step (envC', env', e, c) of
             Estep st -> Dstep (envC, env, ds, SOME (p, st))
          || Etype_error -> Dtype_error
          || Estuck -> Dstuck
        )
    || NONE ->
        (case ds of
             [] -> Dstuck
          || (Dlet p e) :: ds ->
              Dstep (envC, env, ds, SOME (p, (envC, env, e, [])))
          || (Dletrec funs) :: ds ->
              if ~ (ALL_DISTINCT (MAP (\ (x,y,z) . x) funs)) then
                Dtype_error
              else
                Dstep (envC, build_rec_env funs env, ds, NONE)
          || (Dtype tds) :: ds ->
              if check_dup_ctors tds envC then
                Dstep (build_tdefs tds envC, env, ds, NONE)
              else 
                Dtype_error
      )
  ))`;


(* Define a semantic function using the steps *)

val _ = Hol_datatype `
 error_result = 
    Rtype_error
  | Rraise of error`;


val _ = Hol_datatype `
(*  'a *) result =
    Rval of 'a
  | Rerr of error_result`;


(*val e_step_reln : state -> state -> bool*)
(*val small_eval : envC -> envE -> exp -> ctxt list -> v result -> bool*)
(*val d_step_reln : d_state -> d_state -> bool*)
(*val d_small_eval : envC -> envE -> dec list -> (pat * state)option -> envE result -> bool*)

val _ = Define `
 (e_step_reln st1 st2 = 
  (e_step st1 = Estep st2))`;


 val small_eval_defn = Hol_defn "small_eval" `
 
(small_eval cenv env e c (Rval v) =
  ? env'. (RTC e_step_reln) (cenv,env,e,c) (cenv,env',Val v,[]))
/\
(small_eval cenv env e c (Rerr (Rraise err)) =
  ? env'. (RTC e_step_reln) (cenv,env,e,c) (cenv,env',Raise err,[]))
/\
(small_eval cenv env e c (Rerr Rtype_error) =
  ? env' e' c'. 
    (RTC e_step_reln) (cenv,env,e,c) (cenv,env',e',c') /\
    (e_step (cenv,env',e',c') = Etype_error))`;

val _ = Defn.save_defn small_eval_defn;

val _ = Define `
 (d_step_reln st st' = 
  (d_step st = Dstep st'))`;


 val d_small_eval_defn = Hol_defn "d_small_eval" `

(d_small_eval cenv env ds c (Rval env') =
  ? cenv'. (RTC d_step_reln) (cenv,env,ds,c) (cenv',env',[],NONE))
/\
(d_small_eval cenv env ds c (Rerr Rtype_error) =
  ? cenv' env' ds' c'. 
    (RTC d_step_reln) (cenv,env,ds,c) (cenv',env',ds',c') /\
    (d_step (cenv',env',ds',c') = Dtype_error))
/\
(d_small_eval cenv env ds c (Rerr (Rraise err)) =
  ? cenv' env' ds' c'. 
    (RTC d_step_reln) (cenv,env,ds,c) (cenv',env',ds',c') /\
    (d_step (cenv',env',ds',c') = Draise err))`;

val _ = Defn.save_defn d_small_eval_defn;

(*val diverges : envC -> envE -> dec list -> bool*)
val _ = Define `
 (diverges cenv env ds =
  ! cenv' env' ds' c'.
    (RTC d_step_reln) (cenv,env,ds,NONE) (cenv',env',ds',c')
    ==>
    (? cenv'' env'' ds'' c''.
      d_step_reln (cenv',env',ds',c') (cenv'',env'',ds'',c'')))`;


(* ------------------------ Big step semantics -------------------------- *)
(*val evaluate : envC -> envE -> exp -> v result -> bool*)
(*val evaluate_list : envC -> envE -> exp list -> v list result -> bool*)
(*val evaluate_match : envC -> envE -> v -> (pat * exp) list -> v result -> bool*)
(*val evaluate_decs : envC -> envE -> dec list -> envE result -> bool*)

val _ = Hol_reln `

(! cenv env err.
T
==>
evaluate cenv env (Raise err) (Rerr (Rraise err)))

/\

(! cenv env v.
T
==>
evaluate cenv env (Val v) (Rval v))

/\

(! cenv env cn es vs.
do_con_check cenv cn (LENGTH es) /\
evaluate_list cenv env es (Rval vs)
==>
evaluate cenv env (Con cn es) (Rval (Conv cn vs)))

/\

(! cenv env cn es.
~ (do_con_check cenv cn (LENGTH es))
==>
evaluate cenv env (Con cn es) (Rerr Rtype_error))

/\

(! cenv env cn es err.
do_con_check cenv cn (LENGTH es) /\
evaluate_list cenv env es (Rerr err)
==>
evaluate cenv env (Con cn es) (Rerr err))

/\

(! cenv env n v.
(lookup n env = SOME v)
==>
evaluate cenv env (Var n) (Rval v))

/\

(! cenv env n.
(lookup n env = NONE)
==>
evaluate cenv env (Var n) (Rerr Rtype_error))

/\

(! cenv env n e.
T
==>
evaluate cenv env (Fun n e) (Rval (Closure env n e)))

/\

(! cenv env op e1 e2 v1 v2 env' e3 bv.
evaluate cenv env e1 (Rval v1) /\
evaluate cenv env e2 (Rval v2) /\
(do_app env op v1 v2 = SOME (env', e3)) /\
evaluate cenv env' e3 bv
==>
evaluate cenv env (App op e1 e2) bv)

/\

(! cenv env op e1 e2 v1 v2.
evaluate cenv env e1 (Rval v1) /\
evaluate cenv env e2 (Rval v2) /\
(do_app env op v1 v2 = NONE)
==>
evaluate cenv env (App op e1 e2) (Rerr Rtype_error))

/\

(! cenv env op e1 e2 v1 err.
evaluate cenv env e1 (Rval v1) /\
evaluate cenv env e2 (Rerr err)
==>
evaluate cenv env (App op e1 e2) (Rerr err))

/\

(! cenv env op e1 e2 err.
evaluate cenv env e1 (Rerr err)
==>
evaluate cenv env (App op e1 e2) (Rerr err))

/\

(! cenv env op e1 e2 v e' bv.
evaluate cenv env e1 (Rval v) /\
(do_log op v e2 = SOME e') /\
evaluate cenv env e' bv
==>
evaluate cenv env (Log op e1 e2) bv)

/\

(! cenv env op e1 e2 v.
evaluate cenv env e1 (Rval v) /\
(do_log op v e2 = NONE)
==>
evaluate cenv env (Log op e1 e2) (Rerr Rtype_error))

/\

(! cenv env op e1 e2 err.
evaluate cenv env e1 (Rerr err)
==>
evaluate cenv env (Log op e1 e2) (Rerr err))

/\

(! cenv env e1 e2 e3 v e' bv.
evaluate cenv env e1 (Rval v) /\
(do_if v e2 e3 = SOME e') /\
evaluate cenv env e' bv
==>
evaluate cenv env (If e1 e2 e3) bv)

/\

(! cenv env e1 e2 e3 v.
evaluate cenv env e1 (Rval v) /\
(do_if v e2 e3 = NONE)
==>
evaluate cenv env (If e1 e2 e3) (Rerr Rtype_error))

/\


(! cenv env e1 e2 e3 err.
evaluate cenv env e1 (Rerr err)
==>
evaluate cenv env (If e1 e2 e3) (Rerr err))

/\

(! cenv env e pes v bv.
evaluate cenv env e (Rval v) /\
evaluate_match cenv env v pes bv
==>
evaluate cenv env (Mat e pes) bv)

/\

(! cenv env e pes err.
evaluate cenv env e (Rerr err)
==>
evaluate cenv env (Mat e pes) (Rerr err))

/\

(! cenv env n e1 e2 v bv.
evaluate cenv env e1 (Rval v) /\
evaluate cenv (bind n v env) e2 bv
==>
evaluate cenv env (Let n e1 e2) bv)

/\

(! cenv env n e1 e2 err.
evaluate cenv env e1 (Rerr err)
==>
evaluate cenv env (Let n e1 e2) (Rerr err))

/\

(! cenv env funs e bv.
ALL_DISTINCT (MAP (\ (x,y,z) . x) funs) /\
evaluate cenv (build_rec_env funs env) e bv
==>
evaluate cenv env (Letrec funs e) bv)

/\

(! cenv env funs e.
~ (ALL_DISTINCT (MAP (\ (x,y,z) . x) funs))
==>
evaluate cenv env (Letrec funs e) (Rerr Rtype_error))

/\


(! cenv env.
T
==>
evaluate_list cenv env [] (Rval []))

/\

(! cenv env e es v vs.
evaluate cenv env e (Rval v) /\
evaluate_list cenv env es (Rval vs)
==>
evaluate_list cenv env (e::es) (Rval (v::vs)))

/\

(! cenv env e es err.
evaluate cenv env e (Rerr err)
==>
evaluate_list cenv env (e::es) (Rerr err))

/\

(! cenv env e es v err.
evaluate cenv env e (Rval v) /\
evaluate_list cenv env es (Rerr err)
==>
evaluate_list cenv env (e::es) (Rerr err))

/\

(! cenv env v.
T
==>
evaluate_match cenv env v [] (Rerr (Rraise Bind_error)))

/\

(! cenv env v p e pes env' bv.
(pmatch cenv p v env = Match env') /\
evaluate cenv env' e bv
==>
evaluate_match cenv env v ((p,e)::pes) bv)

/\

(! cenv env v p e pes bv.
(pmatch cenv p v env = No_match) /\
evaluate_match cenv env v pes bv
==>
evaluate_match cenv env v ((p,e)::pes) bv)

/\

(! cenv env v p e pes.
(pmatch cenv p v env = Match_type_error)
==>
evaluate_match cenv env v ((p,e)::pes) (Rerr Rtype_error))`;

val _ = Hol_reln `

(! cenv env.
T
==>
evaluate_decs cenv env [] (Rval env))

/\

(! cenv env p e ds v env' r.
evaluate cenv env e (Rval v) /\
(pmatch cenv p v env = Match env') /\
evaluate_decs cenv env' ds r
==>
evaluate_decs cenv env (Dlet p e :: ds) r)

/\

(! cenv env p e ds v.
evaluate cenv env e (Rval v) /\
(pmatch cenv p v env = No_match) 
==>
evaluate_decs cenv env (Dlet p e :: ds) (Rerr (Rraise Bind_error)))

/\

(! cenv env p e ds v.
evaluate cenv env e (Rval v) /\
(pmatch cenv p v env = Match_type_error) 
==>
evaluate_decs cenv env (Dlet p e :: ds) (Rerr (Rtype_error)))

/\

(! cenv env p e ds err.
evaluate cenv env e (Rerr err)
==>
evaluate_decs cenv env (Dlet p e :: ds) (Rerr err))

/\

(! cenv env funs ds r.
ALL_DISTINCT (MAP (\ (x,y,z) . x) funs) /\
evaluate_decs cenv (build_rec_env funs env) ds r
==>
evaluate_decs cenv env (Dletrec funs :: ds) r)

/\

(! cenv env funs ds.
~ (ALL_DISTINCT (MAP (\ (x,y,z) . x) funs))
==>
evaluate_decs cenv env (Dletrec funs :: ds) (Rerr Rtype_error))

/\

(! cenv env tds ds r.
check_dup_ctors tds cenv /\
evaluate_decs (build_tdefs tds cenv) env ds r
==>
evaluate_decs cenv env (Dtype tds :: ds) r)

/\

(! cenv env tds ds.
~ (check_dup_ctors tds cenv)
==>
evaluate_decs cenv env (Dtype tds :: ds) (Rerr Rtype_error))`;

(* ------------------------ Type system --------------------------------- *)

(* The type system does not currently support let polymorphism, but does 
* support polymorphic datatypes *)

(* constructor type environments: each constructor has a type 
 * forall (tyvarN list). t list -> typeN *)
val _ = type_abbrev( "tenvC" , ``: (conN, (tvarN list # t list # typeN)) env``); 
(* Type environments *)
val _ = type_abbrev( "tenvE" , ``: (varN, t) env``);

(* A pattern matches values of a certain type and extends the type environment
 * with the pattern's binders.  The pattern's type does not depend on the input
 * environment *)
(*val type_p : tenvC -> tenvE -> pat -> t -> tenvE -> bool*)

(* A value has a type *)
(*val type_v : tenvC -> v -> t -> bool*)

(* An expression has a type *)
(*val type_e : tenvC -> tenvE -> exp -> t -> bool*)

(* A list of expressions has a list of types *)
(*val type_es : tenvC -> tenvE -> exp list -> t list -> bool*)

(* A value environment has a corresponding type environment.  Since all of the
 * entries in the environment are values, and values have no free variables,
 * each entry in the environment can be typed in the empty environment (if at
 * all) *)
(*val type_env : tenvC -> envE -> tenvE -> bool*)

(* Type a mutually recursive bundle of functions.  Unlike pattern typing, the
 * resulting environment does not extend the input environment, but just
 * represents the functions *)
(*val type_funs : tenvC -> tenvE -> (varN * varN * exp) list -> tenvE -> bool*)

(* Check a declaration and update the top-level environments *)
(*val type_d : tenvC -> tenvE -> dec -> tenvC -> tenvE -> bool*)

(*val type_ds : tenvC -> tenvE -> dec list -> tenvC -> tenvE -> bool*)

(* Check that the operator can have type (t1 -> t2 -> t3) *)
(*val type_op : op -> t -> t -> t -> bool*)
val _ = Define `
 (type_op op t1 t2 t3 =
  (case (op,t1,t2) of
       (Opapp, Tfn t2' t3', _) -> (t2 = t2') /\ (t3 = t3')
    || (Opn _, Tnum, Tnum) -> (t3 = Tnum)
    || (Opb _, Tnum, Tnum) -> (t3 = Tbool)
    || _ -> F
  ))`;


(*val check_ctor_tenv : 
  tenvC -> (tvarN list * typeN * (conN * t list) list) list -> bool*)
val _ = Define `
 (check_ctor_tenv tenvC tds =
  check_dup_ctors tds tenvC /\
  EVERY
    (\ (tvs,tn,ctors) .
       ALL_DISTINCT tvs /\
       EVERY 
         (\ (cn,ts) . (EVERY (check_freevars tvs) ts))
         ctors)
    tds)`;


(*val build_ctor_tenv : (tvarN list * typeN * (conN * t list) list) list -> tenvC*) 
val _ = Define `
 (build_ctor_tenv tds = 
  FLAT
    (MAP
       (\ (tvs,tn,ctors) .
          MAP (\ (cn,ts) . (cn,(tvs,ts,tn))) ctors)
       tds))`;


val _ = Hol_reln `

(! cenv tenv n t.
T
==>
type_p cenv tenv (Pvar n) t (bind n t tenv))

/\

(! cenv tenv b.
T
==>
type_p cenv tenv (Plit (Bool b)) Tbool tenv)

/\

(! cenv tenv n.
T
==>
type_p cenv tenv (Plit (Num n)) Tnum tenv)

/\

(! cenv tenv cn ps ts tvs tn ts' tenv'.
(LENGTH ts' = LENGTH tvs) /\
type_ps cenv tenv ps (MAP (type_subst (ZIP ( tvs, ts'))) ts) tenv' /\
(lookup cn cenv = SOME (tvs, ts, tn))
==>
type_p cenv tenv (Pcon cn ps) (Tapp ts' tn) tenv')

/\

(! cenv tenv.
T
==>
type_ps cenv tenv [] [] tenv)

/\

(! cenv tenv p ps t ts tenv' tenv''.
type_p cenv tenv p t tenv' /\
type_ps cenv tenv' ps ts tenv''
==>
type_ps cenv tenv (p::ps) (t::ts) tenv'')`;

val _ = Hol_reln `

(! cenv b.
T
==>
type_v cenv (Lit (Bool b)) Tbool)

/\
(! cenv n.
T
==>
type_v cenv (Lit (Num n)) Tnum)

/\

(! cenv cn vs tvs tn ts' ts.
(LENGTH tvs = LENGTH ts') /\
type_vs cenv vs (MAP (type_subst (ZIP ( tvs, ts'))) ts) /\
(lookup cn cenv = SOME (tvs, ts, tn))
==>
type_v cenv (Conv cn vs) (Tapp ts' tn))

/\

(! cenv env tenv n e t1 t2.
type_env cenv env tenv /\
type_e cenv (bind n t1 tenv) e t2
==>
type_v cenv (Closure env n e) (Tfn t1 t2))

/\

(! cenv env funs n t tenv tenv'.
type_env cenv env tenv /\
type_funs cenv (merge tenv' tenv) funs tenv' /\
(lookup n tenv' = SOME t)
==>
type_v cenv (Recclosure env funs n) t)

/\

(! cenv tenv err t.
T
==>
type_e cenv tenv (Raise err) t)

/\

(! cenv tenv v t.
type_v cenv v t
==>
type_e cenv tenv (Val v) t)

/\

(! cenv tenv cn es tvs tn ts' ts.
(LENGTH tvs = LENGTH ts') /\
type_es cenv tenv es (MAP (type_subst (ZIP ( tvs, ts'))) ts) /\
(lookup cn cenv = SOME (tvs, ts, tn))
==>
type_e cenv tenv (Con cn es) (Tapp ts' tn))

/\

(! cenv tenv n t.
(lookup n tenv = SOME t)
==>
type_e cenv tenv (Var n) t)

/\

(! cenv tenv n e t1 t2.
type_e cenv (bind n t1 tenv) e t2
==>
type_e cenv tenv (Fun n e) (Tfn t1 t2))

/\

(! cenv tenv op e1 e2 t1 t2 t3.
type_e cenv tenv e1 t1 /\
type_e cenv tenv e2 t2 /\
type_op op t1 t2 t3
==>
type_e cenv tenv (App op e1 e2) t3)

/\

(! cenv tenv l e1 e2.
type_e cenv tenv e1 Tbool /\
type_e cenv tenv e2 Tbool
==>
type_e cenv tenv (Log l e1 e2) Tbool)

/\

(! cenv tenv e1 e2 e3 t.
type_e cenv tenv e1 Tbool /\
type_e cenv tenv e2 t /\
type_e cenv tenv e3 t
==>
type_e cenv tenv (If e1 e2 e3) t)

/\

(! cenv tenv e pes t1 t2.
type_e cenv tenv e t1 /\
(! ((p,e) :: LIST_TO_SET pes) tenv'.
   type_p cenv tenv p t1 tenv' /\
   type_e cenv tenv' e t2)
==>
type_e cenv tenv (Mat e pes) t2)

/\

(! cenv tenv n e1 e2 t1 t2.
type_e cenv tenv e1 t1 /\
type_e cenv (bind n t1 tenv) e2 t2
==>
type_e cenv tenv (Let n e1 e2) t2)

/\

(! cenv tenv funs e t tenv'.
type_funs cenv (merge tenv' tenv) funs tenv' /\
type_e cenv (merge tenv' tenv) e t
==>
type_e cenv tenv (Letrec funs e) t)

/\

(! cenv tenv.
T
==>
type_es cenv tenv [] [])

/\

(! cenv tenv e es t ts.
type_e cenv tenv e t /\
type_es cenv tenv es ts
==>
type_es cenv tenv (e::es) (t::ts))

/\

(! cenv.
T
==>
type_vs cenv [] [])

/\

(! cenv v vs t ts.
type_v cenv v t /\
type_vs cenv vs ts
==>
type_vs cenv (v::vs) (t::ts))

/\

(! cenv.
T
==>
type_env cenv [] [])

/\

(! cenv n v env t tenv.
type_e cenv [] (Val v) t /\
type_env cenv env tenv
==>
type_env cenv (bind n v env) (bind n t tenv))

/\

(! cenv env.
T
==>
type_funs cenv env [] emp)

/\

(! cenv env fn n e funs env' t1 t2.
type_e cenv (bind n t1 env) e t2 /\
type_funs cenv env funs env' /\
(lookup fn env' = NONE)
==>
type_funs cenv env ((fn, n, e)::funs) (bind fn (Tfn t1 t2) env'))`;


val _ = Hol_reln `

(! cenv tenv p e t tenv'.
type_p cenv tenv p t tenv' /\
type_e cenv tenv e t
==>
type_d cenv tenv (Dlet p e) emp tenv')

/\

(! cenv tenv funs tenv'.
type_funs cenv (merge tenv' tenv) funs tenv'
==>
type_d cenv tenv (Dletrec funs) emp (merge tenv' tenv))

/\

(! cenv tenv tdecs.
check_ctor_tenv cenv tdecs
==>
type_d cenv tenv (Dtype tdecs) (build_ctor_tenv tdecs) tenv)`;

val _ = Hol_reln `

(! cenv tenv.
T
==>
type_ds cenv tenv [] emp tenv)

/\

(! cenv tenv d ds cenv' tenv' cenv'' tenv''.
type_d cenv tenv d cenv' tenv' /\
type_ds (merge cenv' cenv) tenv' ds cenv'' tenv''
==>
type_ds cenv tenv (d::ds) (merge cenv' cenv'') tenv'')`;

(* --------- Auxiliary definitions used in the type soundness proofs -------- *)

(* An evaluation context has the second type when its hole is filled with a
 * value of the first type. *)
(*val type_ctxt : tenvC -> tenvE -> ctxt_frame -> t -> t -> bool*)
(*val type_ctxts : tenvC -> ctxt list -> t -> t -> bool*)
(*val type_state : tenvC -> state -> t -> bool*)

val _ = Hol_reln `

(! cenv tenv e op t1 t2 t3.
type_e cenv tenv e t2 /\
type_op op t1 t2 t3
==>
type_ctxt cenv tenv (Capp1 op () e) t1 t3)

/\

(! cenv tenv op v t1 t2 t3.
type_e cenv tenv (Val v) t1 /\
type_op op t1 t2 t3
==>
type_ctxt cenv tenv (Capp2 op v ()) t2 t3)

/\

(! cenv tenv op e.
type_e cenv tenv e Tbool
==>
type_ctxt cenv tenv (Clog op () e) Tbool Tbool)

/\

(! cenv tenv e1 e2 t.
type_e cenv tenv e1 t /\
type_e cenv tenv e2 t
==>
type_ctxt cenv tenv (Cif () e1 e2) Tbool t)

/\

(! cenv tenv t1 t2 pes.
(! ((p,e) :: LIST_TO_SET pes) tenv'.
   type_p cenv tenv p t1 tenv' /\
   type_e cenv tenv' e t2)
==>
type_ctxt cenv tenv (Cmat () pes) t1 t2)

/\

(! cenv tenv e t1 t2 n.
type_e cenv (bind n t1 tenv) e t2
==>
type_ctxt cenv tenv (Clet n () e) t1 t2)

/\

(! cenv tenv cn vs es ts1 ts2 t tn ts' tvs.
(LENGTH tvs = LENGTH ts') /\
type_es cenv tenv (REVERSE (MAP Val vs)) 
        (MAP (type_subst (ZIP ( tvs, ts'))) ts1) /\
type_es cenv tenv es (MAP (type_subst (ZIP ( tvs, ts'))) ts2) /\
(lookup cn cenv = SOME (tvs, ts1++([t]++ts2), tn))
==>
type_ctxt cenv tenv (Ccon cn vs () es) (type_subst (ZIP ( tvs, ts')) t) 
          (Tapp ts' tn))`;

val _ = Hol_reln `

(! tenvC t.
T
==>
type_ctxts tenvC [] t t)

/\

(! tenvC c env cs tenv t1 t2 t3.
type_env tenvC env tenv /\
type_ctxt tenvC tenv c t1 t2 /\
type_ctxts tenvC cs t2 t3
==>
type_ctxts tenvC ((c,env)::cs) t1 t3)`;

val _ = Hol_reln `

(! tenvC envC env e c t1 t2 tenv.
type_ctxts tenvC c t1 t2 /\
type_env tenvC env tenv /\
type_e tenvC tenv e t1
==>
type_state tenvC (envC, env, e, c) t2)`;

val _ = Hol_reln `

(! tenvC envC env ds tenvC' tenv tenv'.
type_env tenvC env tenv /\
type_ds tenvC tenv ds tenvC' tenv'
==>
type_d_state tenvC (envC, env, ds, NONE) tenvC' tenv')

/\

(! tenvC envC env ds tenvC' tenv tenv' p env' e c t tenv''.
type_env tenvC env tenv /\
type_state tenvC (envC,env',e,c) t /\
type_p tenvC tenv p t tenv' /\
type_ds tenvC tenv' ds tenvC' tenv''
==>
type_d_state tenvC (envC, env, ds, SOME (p, (envC,env',e,c))) tenvC' tenv'')`;

(* ------ Auxiliary relations for proving big/small step equivalence ------ *)

(*val evaluate_ctxt : envC -> envE -> ctxt_frame -> v -> v result -> bool*)
(*val evaluate_ctxts : envC -> ctxt list -> v -> v result -> bool*)
(*val evaluate_state : state -> v result -> bool*)

val _ = Hol_reln `

(! cenv env op e v bv.
evaluate cenv env (App op (Val v) e) bv
==>
evaluate_ctxt cenv env (Capp1 op () e) v bv)

/\

(! cenv env op v1 v2 bv.
evaluate cenv env (App op (Val v1) (Val v2)) bv
==>
evaluate_ctxt cenv env (Capp2 op v1 ()) v2 bv)

/\

(! cenv env op e v bv.
evaluate cenv env (Log op (Val v) e) bv
==>
evaluate_ctxt cenv env (Clog op () e) v bv)

/\

(! cenv env e1 e2 v bv.
evaluate cenv env (If (Val v) e1 e2) bv
==>
evaluate_ctxt cenv env (Cif () e1 e2) v bv)

/\

(! cenv env pes v bv.
evaluate cenv env (Mat (Val v) pes) bv
==>
evaluate_ctxt cenv env (Cmat () pes) v bv)

/\

(! cenv env n e v bv.
evaluate cenv env (Let n (Val v) e) bv
==>
evaluate_ctxt cenv env (Clet n () e) v bv)

/\

(! cenv env n vs es v bv.
evaluate cenv env (Con n (MAP Val (REVERSE vs) ++ ([Val v] ++ es))) bv
==>
evaluate_ctxt cenv env (Ccon n vs () es) v bv)`;

val _ = Hol_reln `

(! cenv v.
T
==>
evaluate_ctxts cenv [] v (Rval v))

/\

(! cenv c cs env v v' bv.
evaluate_ctxt cenv env c v (Rval v') /\
evaluate_ctxts cenv cs v' bv 
==>
evaluate_ctxts cenv ((c,env)::cs) v bv)

/\

(! cenv c cs v env err.
evaluate_ctxt cenv env c v (Rerr err)
==>
evaluate_ctxts cenv ((c,env)::cs) v (Rerr err))`;

val _ = Hol_reln `

(! cenv env e c v bv.
evaluate cenv env e (Rval v) /\
evaluate_ctxts cenv c v bv
==>
evaluate_state (cenv, env, e, c) bv)

/\

(! cenv env e c err.
evaluate cenv env e (Rerr err)
==>
evaluate_state (cenv, env, e, c) (Rerr err))`;
val _ = export_theory()

