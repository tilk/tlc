(**************************************************************************
* TLC: A library for Coq                                                  *
* Lists accessed with integers (not nat) and using LibBag typeclasses     *
**************************************************************************)

Set Implicit Arguments. 
Generalizable Variables A B.
Require Import LibTactics LibLogic LibOperation LibReflect
  LibProd LibNat LibInt LibOption LibWf.
Require Export LibList LibNat.
Require Import LibInt.
Require Export LibBag.

Open Local Scope comp_scope.


(* ********************************************************************** *)
(** * List operations using indices in Z *)

Section Zindices.
Variables A : Type.
Implicit Types x : A.
Implicit Types l : list A.
Implicit Types i : int.
Ltac auto_tilde ::= eauto with maths.


(* ---------------------------------------------------------------------- *)
(** * Definitions *)

(** Functions *)

Definition length (l:list A) := 
  (length l) : int.

Definition nth `{Inhab A} (i:int) (l:list A) :=
  If i < 0 then arbitrary else nth (abs i) l. 

Definition update (i:int) (v:A) (l:list A) :=
  If i < 0 then l else LibList.update (abs i) v l.

Definition make (n:int) (v:A) :=
  If n < 0 then arbitrary else make (abs n) v.

End Zindices.


(* ---------------------------------------------------------------------- *)
(** ** Typeclasses read & update operations, binds and index predicates *)

(** Note: we also define [card] as [length], but we use [length] everywhere
    in the specifications. *)

Definition card_impl A (l:list A) : nat :=
  LibList.length l. 
  (* todo: should it return a nat or an int? might change... *)

Definition read_impl `{Inhab A} (l:list A) (i:int) : A :=
  nth i l.

Definition update_impl A (l:list A) (i:int) (v:A) : list A :=
  update i v l.

Definition index_impl A (l:list A) (i:int) : Prop :=
  index (LibList.length l : int) i.


Instance card_inst : forall A, BagCard (list A).
 constructor. rapply (@card_impl A). Defined.
Instance read_inst : forall `{Inhab A}, BagRead int A (list A).
 constructor. rapply (@read_impl A H). Defined.
Instance update_inst : forall A, BagUpdate int A (list A).
  constructor. rapply (@update_impl A). Defined.
Instance index_inst : forall A, BagIndex int (list A).
  constructor. rapply (@index_impl A). Defined.

Global Opaque card_inst read_inst update_inst index_inst.

(* LATER
Definition binds_impl A (l:list A) (i:int) (v:A) : Prop := 
  index_impl l i /\ nth i l = v.
  (* deprecated:  ZNth i l v. *)
Instance binds_inst : forall A, BagBinds int A (list A).
  constructor. rapply (@binds_impl A). Defined.
Global Opaque binds_inst
*)

(* ---------------------------------------------------------------------- *)
(** * Properties of length *)

Section LengthProperties.
Variable A : Type.
Implicit Types l : list A.
Ltac auto_tilde ::= eauto with maths.

Lemma length_nil : 
  length (@nil A) = 0.
Proof. auto. Qed.
Lemma length_cons : forall x l,
  length (x::l) = 1 + length l.
Proof. intros. unfold length. rew_length~. Qed.
Lemma length_app : forall l1 l2,
  length (l1 ++ l2) = length l1 + length l2.
Proof. intros. unfold length. rew_length~. Qed.
Lemma length_last : forall x l,
  length (l & x) = 1 + length l.
Proof. intros. unfold length. rew_length~. Qed.
Lemma length_zero_inv : forall l,
  length l = 0 -> l = nil.
Proof. intros. unfolds length. applys~ LibList.length_zero_inv. Qed.

End LengthProperties.

Hint Rewrite length_nil length_cons length_app
 length_last length_rev : rew_length.
Hint Rewrite length_nil length_cons length_app
 length_last length_rev : rew_list.


(* ---------------------------------------------------------------------- *)
(** * Properties of zmake *)

Section MakeProperties.
Transparent read_inst.

Lemma read_make : forall `{Inhab A} (i n:int) (v:A),
  index n i -> (make n v)[i] = v.
Proof.
  introv N. rewrite int_index_def in N. unfold make, read_inst, read_impl, nth.
  case_if. math. simpl. case_if. math.
  applys nth_make. forwards: Zabs_nat_lt i n; try math.
Qed.

Lemma length_make : forall A (n:int) (v:A),
  n >= 0 ->
  length (make n v) = n :> int.
Proof.
  introv N. unfold make. case_if. math.
  unfold length. rewrite LibList.length_make.
  rewrite~ abs_pos.
Qed.

End MakeProperties.


(* ---------------------------------------------------------------------- *)
(** * Properties of update *)

Section UpdateProperties.
Transparent index_inst read_inst update_inst.

Lemma length_update : forall A (l:list A) (i:int) (v:A),
  length (l[i:=v]) = length l.
Proof.
  intros. unfold update_inst, update_impl, length, update. simpl.
  case_if. math. rewrite~ length_update.
Qed.

Lemma read_update_case : forall `{Inhab A} (l:list A) (i j:int) (v:A),
  index l j -> l[i:=v][j] = (If i = j then v else l[j]).
Proof.
  introv. unfold index_inst, index_impl, update_inst, update_impl, update,
    read_inst, read_impl, nth. simpl. introv N. rewrite int_index_def in N.
  case_if. math.
  case_if. case_if. auto. case_if. 
    rewrite~ nth_update_eq. apply nat_int_lt. rewrite abs_pos; try math.
    rewrite~ nth_update_neq. apply nat_int_lt. rewrite abs_pos; try math.
      apply nat_int_neq. rewrite abs_pos; try math. rewrite abs_pos; try math.
Qed.

Lemma read_update_eq : forall `{Inhab A} (l:list A) (i:int) (v:A),
  index l i -> (l[i:=v])[i] = v.
Proof. introv N. rewrite~ read_update_case. case_if~. Qed.

Lemma read_update_neq : forall `{Inhab A} (l:list A) (i j:int) (v:A),
  index l j -> (i <> j) -> (l[i:=v])[j] = l[j].
Proof. introv N. rewrite~ read_update_case. case_if; auto_false~. Qed.

End UpdateProperties.


(* ---------------------------------------------------------------------- *)
(** * Normalization tactics *)

(** [rew_arr] is a light normalization tactic for array *)

(* TODO: rename to [rew_array_nocase] *) 
Hint Rewrite @read_make @length_make @length_update @read_update_eq 
  : rew_arr.

Tactic Notation "rew_arr" := 
  autorewrite with rew_arr.
Tactic Notation "rew_arr" "in" hyp(H) := 
  autorewrite with rew_arr in H.
Tactic Notation "rew_arr" "in" "*" := 
  autorewrite_in_star_patch ltac:(fun tt => autorewrite with rew_arr).
  (* autorewrite with rew_arr in *. *)

Tactic Notation "rew_arr" "~" :=
  rew_arr; auto_tilde.
Tactic Notation "rew_arr" "*" :=
  rew_arr; auto_star.
Tactic Notation "rew_arr" "~" "in" hyp(H) :=
  rew_arr in H; auto_tilde.
Tactic Notation "rew_arr" "*" "in" hyp(H) :=
  rew_arr in H; auto_star.
Tactic Notation "rew_arr" "~" "in" "*" :=
  rew_arr in *; auto_tilde.
Tactic Notation "rew_arr" "*" "in" "*" :=
  rew_arr in *; auto_star.

(** [rew_array] is a normalization tactic for array *)

Hint Rewrite @read_make @length_make @length_update @read_update_eq
  @read_update_case : rew_array.

Tactic Notation "rew_array" := 
  autorewrite with rew_array.
Tactic Notation "rew_array" "in" hyp(H) := 
  autorewrite with rew_array in H.
Tactic Notation "rew_array" "in" "*" := 
  autorewrite_in_star_patch ltac:(fun tt => autorewrite with rew_array).
  (* autorewrite with rew_array in *. *)

Tactic Notation "rew_array" "~" :=
  rew_array; auto_tilde.
Tactic Notation "rew_array" "*" :=
  rew_array; auto_star.
Tactic Notation "rew_array" "~" "in" hyp(H) :=
  rew_array in H; auto_tilde.
Tactic Notation "rew_array" "*" "in" hyp(H) :=
  rew_array in H; auto_star.
Tactic Notation "rew_array" "~" "in" "*" :=
  rew_array in *; auto_tilde.
Tactic Notation "rew_array" "*" "in" "*" :=
  rew_array in *; auto_star.

(* ---------------------------------------------------------------------- *)
(** * Valid index predicate *)

Section IndexProperties.
Transparent index_inst.

Lemma index_def : forall A (l:list A) i,
  index l i = index (length l : int) i.
Proof. auto. Qed. 

Lemma index_length_unfold : forall A (l:list A) i,
  index (length l : int) i -> index l i.
Proof. introv H. rewrite* index_def. Qed.

Lemma index_length_eq : forall A (l:list A) (n:int) i,
  index n i -> n = length l -> index l i.
Proof. intros. subst. rewrite~ index_def. Qed.

Lemma index_bounds : forall A (l:list A) i,
  index l i = (0 <= i < length l).
Proof. auto. Qed. 

Lemma index_bounds_impl : forall A (l:list A) i,
  0 <= i < length l -> index l i.
Proof. intros. rewrite~ index_bounds. Qed.

Lemma index_update : forall A (l:list A) i j (v:A),
  index l i -> index (l[j:=v]) i.
Proof. intros. rewrite index_def in *. rewrite~ length_update. Qed.

Lemma index_zmake : forall A n i (v:A),
  index n i -> index (make n v) i.
Proof.
  introv H. rewrite index_def. rewrite int_index_def in H.
  rewrite~ length_make. math.
Qed.

End IndexProperties.


(* ---------------------------------------------------------------------- *)
(** * count *)

(* TODO: complete definitions and proofs, which are used by CFML/Dijstra *)

Require Import LibWf.

(* TODO: implement a non-decidable version of count *)

Parameter count : forall A (P:A->Prop) (l:list A), int.

(* currently not used
Parameter count_make : forall A (f:A->Prop) n v,
  count f (make n v) = (If f v then n else 0).
*)

Parameter count_update : forall `{Inhab A} (P:A->Prop) (l:list A) (i:int) v,
  index l i ->
  count P (l[i:=v]) = count P l
    - (If P (l[i]) then 1 else 0)
    + (If P v then 1 else 0).

Parameter count_bounds : forall `{Inhab A} (l:list A) (P:A->Prop),
  0 <= count P l <= length l.

(** The following lemma is used to argue that the update to a sequence,
    when writing a value that satisfies [P] in place of one that did not
    satisfy [P], decreases the total number of values that satisfying 
    [P] in the sequence. *)

Lemma count_upto : forall `{Inhab A} (P:A->Prop) (l:list A) (n i:int) (v:A),
  ~ P (l[i]) -> P v -> index l i -> (length l <= n)%Z ->
  upto n (count P (l[i:=v])) (count P l).
Proof.
  introv Ni Pv Hi Le. forwards K: (count_bounds (l[i:=v]) P). split.
  rewrite length_update in K. math.
  lets M: (@count_update A _). rewrite~ M. clear M. 
  do 2 (case_if; tryfalse). math.
Qed.



(* ---------------------------------------------------------------------- *)
(* LATER:

Lemma isTrue_eq_list : forall A {IA:Inhab A} (L1 L2:list A),
  len L1 = len L2 ->
  ((forall i, index (len L1) i -> L1[i] = L2[i]) ->
  (L1 = L2)).

*)





(* ********************************************************************** *)
(** * DEPRECATED -- List predicates using indices in Z *)

Section ZindicesOld.
Variables A : Type.
Implicit Types x : A.
Implicit Types l : list A.
Implicit Types i : int.
Ltac auto_tilde ::= eauto with maths.

(* ---------------------------------------------------------------------- *)
(** * DEPRECATED *)

(** Predicates *)

Definition ZInbound i l := 
  0 <= i /\ i < length l.

Definition ZNth i l x := 
  Nth (abs i) l x /\ 0 <= i.

Definition ZUpdate i x l l' :=
  Update (abs i) x l l' /\ 0 <= i.


(* ---------------------------------------------------------------------- *)
(** * DEPRECATED -- Znth *)

Lemma ZNth_here : forall i x l,
  i = 0 -> ZNth i (x::l) x.
Proof. intros. subst. split~. constructor. Qed. 

Lemma ZNth_zero : forall x l,
  ZNth 0 (x::l) x.
Proof. intros. apply~ ZNth_here. Qed.

Lemma ZNth_next : forall i j x y l,
  ZNth j l x -> i = j+1 -> ZNth i (y::l) x.
Proof.
  introv [H P] M. subst. split~.
  applys_eq* Nth_next 3. rew_abs_pos~. 
Qed.
 
Lemma ZNth_app_l : forall i x l1 l2,
  ZNth i l1 x -> ZNth i (l1 ++ l2) x.
Proof. introv [H P]. split~. apply~ Nth_app_l. Qed.

Lemma ZNth_app_r : forall i j x l1 l2,
  ZNth j l2 x -> i = j + length l1 -> ZNth i (l1 ++ l2) x.
Proof.
  introv [H P]. unfold length. split~. subst. 
  apply* Nth_app_r. rew_abs_pos~. 
Qed.

Lemma ZNth_nil_inv : forall i x,
  ZNth i nil x -> False.
Proof. introv [H P]. apply* Nth_nil_inv. Qed.

Lemma ZNth_cons_inv : forall i x l,
  ZNth i l x -> 
     (exists q, l = x::q /\ i = 0)
  \/ (exists y q j, l = y::q /\ ZNth j q x /\ i = j+1).
Proof.
  introv [H P]. forwards~: (@abs_pos i).
  destruct (Nth_cons_inv H); unpack.
  left. exists___. split~. 
  right. exists___. splits~.
   split. rewrite* abs_pos_nat. math.
   math.
Qed.

Lemma ZNth_inbound : forall i l,
   ZInbound i l -> exists x, ZNth i l x.
Proof.
  introv [P U]. unfolds length. gen_eq n: (abs i). 
  gen i l. induction n; intros; 
    forwards~: (@abs_pos i); destruct l; rew_length in U; try math.
  math_rewrite (i = 0). exists __. split~. constructor.
  forwards~ [x [M P']]: (>> IHn (i-1) l).
    forwards~: (@abs_spos i).
    exists x. split~. rewrite~ (@abs_spos i). constructor~.
Qed.


(* ---------------------------------------------------------------------- *)
(** * DEPRECATED -- ZInbound *)

Lemma ZInbound_zero : forall x l,
  ZInbound 0 (x::l).
Proof. split; unfold length; rew_list~. Qed. 

Lemma ZInbound_zero_not_nil : forall x l,
  l <> nil -> ZInbound 0 l.
Proof.
  intros. split~. unfold length.
  destruct l; tryfalse. rew_list~. 
Qed.

Lemma ZInbound_cons : forall i j x l,
  ZInbound j l -> j = i-1 -> ZInbound i (x::l).
Proof. introv [P U] H. split; rew_list~. Qed. 

Lemma ZInbound_nil_inv : forall i,
  ZInbound i nil -> False.
Proof. introv [P U]. rew_list in U. math. Qed.

Lemma ZInbound_cons_inv : forall i x l,
  ZInbound i (x::l) -> i = 0 \/ (i <> 0 /\ ZInbound (i-1) l).
Proof.
  introv [P U]. rew_length in U. tests: (i = 0).
    left~.
    right~. split. math. split~.
Qed.

Lemma ZInbound_cons_pos_inv : forall i x l,
  ZInbound i (x::l) -> i <> 0 -> ZInbound (i-1) l.
Proof.
  introv H P. destruct* (ZInbound_cons_inv H).
Qed.

Lemma ZInbound_one_pos_inv : forall i x,
  ZInbound i (x::nil) -> i <> 0 -> False.
Proof.
  intros. eapply ZInbound_nil_inv. apply* ZInbound_cons_pos_inv.
Qed.

Lemma ZInbound_app_l_inv : forall i l1 l2,
  ZInbound i (l1++l2) -> i < length l1 -> ZInbound i l1.
Proof. introv [P U] H. split~. Qed. 

Lemma ZInbound_app_r_inv : forall i j l1 l2,
  ZInbound j (l1++l2) -> j = length l1 + i -> i >= 0 -> ZInbound i l2.
Proof. introv [P U] R H. rew_length in U. split~. Qed.


(* ---------------------------------------------------------------------- *)
(** * DEPRECATED -- ZUpdate *)

Lemma ZUpdate_here : forall x y l,
  ZUpdate 0 x (y::l) (x::l).
Proof. split~. apply Update_here. Qed.

Lemma ZUpdate_cons : forall i j x y l l',
  ZUpdate j x l l' -> i = j+1 -> ZUpdate i x (y::l) (y::l').
Proof.
  introv [U P] H. split~. applys_eq~ Update_cons 4.
  subst. rew_abs_pos~.
Qed.  

Lemma ZUpdate_app_l : forall i x l1 l1' l2,
  ZUpdate i x l1 l1' -> ZUpdate i x (l1++l2) (l1'++l2).
Proof. introv [U P]. split~. apply~ Update_app_l. Qed.

Lemma ZUpdate_app_r : forall i j x l1 l2 l2',
  ZUpdate j x l2 l2' -> i = j + length l1 -> ZUpdate i x (l1++l2) (l1++l2').
Proof.
  introv [U P] H. unfolds length. split~. apply~ Update_app_r. 
  subst. rew_abs_pos~.
Qed.

Lemma ZUpdate_not_nil : forall i x l1 l2,
  ZUpdate i x l1 l2 -> l2 <> nil.
Proof. introv [U P]. apply~ Update_not_nil. Qed.

Lemma ZUpdate_length : forall i x l l',
  ZUpdate i x l l' -> length l = length l'.
Proof.
  introv [U P]. unfolds length.
  forwards~: Update_length. 
Qed. 


End ZindicesOld.
