(******************************************************************************)
(* Copyright (c) 2022 Steven Keuchel                                          *)
(* All rights reserved.                                                       *)
(*                                                                            *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are     *)
(* met:                                                                       *)
(*                                                                            *)
(* 1. Redistributions of source code must retain the above copyright notice,  *)
(*    this list of conditions and the following disclaimer.                   *)
(*                                                                            *)
(* 2. Redistributions in binary form must reproduce the above copyright       *)
(*    notice, this list of conditions and the following disclaimer in the     *)
(*    documentation and/or other materials provided with the distribution.    *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        *)
(* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  *)
(* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR *)
(* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR          *)
(* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,      *)
(* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,        *)
(* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR         *)
(* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF     *)
(* LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING       *)
(* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         *)
(* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               *)
(******************************************************************************)

From Equations Require Import
     Equations.
From Em Require Import
     Definitions Context Environment Prelude STLC Triangular.
Import SigTNotations.
Import ctx.notations.

Set Implicit Arguments.

#[local] Arguments Ty_hole {Σ i} xIn.
#[local] Arguments Ty_bool {Σ}.
#[local] Arguments Ty_func {Σ}.
#[local] Open Scope indexed_scope.

Reserved Notation "w1 ⊒ˢ w2" (at level 80).

Module Sub.

  Definition Sub (w1 w2 : World) : Type :=
    @env.Env nat (fun _ => Ty w2) w1.
  Local Notation "w1 ⊒ˢ w2" := (Sub w1 w2).

  Definition Box (A : TYPE) : TYPE :=
    fun w0 => forall w1, w0 ⊒ˢ w1 -> A w1.
  Local Notation "□ A" := (Box A) (at level 9, format "□ A", right associativity).

  #[local] Notation subst t θ := (persist _ t _ θ) (only parsing).

  #[export] Instance lk_sub : Lk Sub :=
    fun w1 w2 r x xIn => env.lookup r xIn.

  #[export] Instance thick_sub : Thick Sub :=
    fun w x xIn s => env.tabulate (thickIn xIn s).
  Definition thin {w x} (xIn : x ∈ w) : w - x ⊒ˢ w :=
    env.tabulate (fun y yIn => Ty_hole (ctx.in_thin xIn yIn)).

  #[export] Instance refl_sub : Refl Sub :=
    fun w => env.tabulate (fun _ => Ty_hole).
  #[export] Instance trans_sub : Trans Sub :=
    fix trans {w0 w1 w2} ζ1 ζ2 {struct ζ1} :=
      match ζ1 with
      | env.nil         => env.nil
      | env.snoc ζ1 x t => env.snoc (trans ζ1 ζ2) x (persist _ t _ ζ2)
      end.
  #[export] Instance step_sub : Step Sub :=
    fun w x => thin ctx.in_zero.

  Definition up1 {w0 w1} (r01 : Sub w0 w1) {n} : Sub (w0 ▻ n) (w1 ▻ n) :=
    env.snoc (env.map (fun _ (t : Ty _) => persist _ t _ step) r01) n (Ty_hole ctx.in_zero).

  Ltac foldlk :=
    change_no_check (env.lookup ?x ?y) with (lk x y).

  Lemma lk_refl {w x} (xIn : x ∈ w)  :
    lk refl xIn = Ty_hole xIn.
  Proof. apply (env.lookup_tabulate (fun _ => Ty_hole)). Qed.

  Lemma lk_trans {w1 w2 w3 x} (xIn : x ∈ w1) (ζ1 : w1 ⊒ˢ w2) (ζ2 : w2 ⊒ˢ w3) :
    lk (trans ζ1 ζ2) xIn = persist _ (lk ζ1 xIn) _ ζ2.
  Proof. induction ζ1; destruct (ctx.view xIn); cbn; now foldlk. Qed.

  Lemma lk_thin {w x y} (xIn : x ∈ w) (yIn : y ∈ w - x) :
    lk (thin xIn) yIn = Ty_hole (ctx.in_thin xIn yIn).
  Proof. unfold lk, lk_sub, thin. now rewrite env.lookup_tabulate. Qed.

  Lemma lk_thick {w x y} (xIn : x ∈ w) (t : Ty _) (yIn : y ∈ w) :
    lk (thick x t) yIn = thickIn xIn t yIn.
  Proof. unfold lk, lk_sub, thick, thick_sub. now rewrite env.lookup_tabulate. Qed.

  #[export] Instance persist_preorder_sub : PersistPreOrder Sub Ty.
  Proof.
    constructor; intros w t *.
    - induction t; cbn; f_equal; now rewrite ?lk_refl.
    - induction t; cbn; f_equal; now rewrite ?lk_trans.
  Qed.

  #[export] Instance preorder_sub : PreOrder Sub.
  Proof.
    constructor.
    - intros. apply env.lookup_extensional. intros. foldlk.
      now rewrite lk_trans, lk_refl.
    - intros. apply env.lookup_extensional. intros. foldlk.
      now rewrite lk_trans, persist_refl.
    - intros. apply env.lookup_extensional. intros. foldlk.
      now rewrite ?lk_trans, persist_trans.
  Qed.

  #[export] Instance InstSub : forall w, Inst (Sub w) (Assignment w) :=
    fun w0 w1 r ι => env.map (fun _ (t : Ty w1) => inst t ι) r.
    (* fix instsub {w0 w1} (r : Sub w0 w1) (ι : Assignment w1) {struct r} := *)
    (*   match r with *)
    (*   | env.nil        => env.nil *)
    (*   | env.snoc r _ t => env.snoc (inst (Inst := @instsub _) r ι) _ (inst t ι) *)
    (*   end. *)

  Lemma comp_thin_thick {w x} (xIn : x ∈ w) (s : Ty (w - x)) :
    trans (thin xIn) (thick x s) = refl.
  Proof.
    apply env.lookup_extensional. intros y yIn. foldlk.
    rewrite lk_trans, lk_refl, lk_thin. cbn.
    rewrite lk_thick. unfold thickIn.
    now rewrite ctx.occurs_check_view_thin.
  Qed.

  Lemma thin_thick_pointful {w x} (xIn : x ∈ w) (s : Ty (w - x)) (t : Ty (w - x)) :
    subst (subst t (thin xIn)) (thick x s) = t.
  Proof. now rewrite <- persist_trans, comp_thin_thick, persist_refl. Qed.

  Lemma subst_thin {w x} (xIn : x ∈ w) (T : Ty (w - x)) :
    Triangular.thin xIn T = subst T (thin xIn).
  Proof. induction T; cbn; f_equal; now rewrite ?lk_thin. Qed.

  Section Triangular.
    Import (hints) Tri.

    Fixpoint triangular {w1 w2} (ζ : w1 ⊒⁻ w2) : w1 ⊒ˢ w2 :=
      match ζ with
      | Tri.refl       => refl
      | Tri.cons x t ζ => trans (thick _ t) (triangular ζ)
      end.

    Lemma triangular_trans {w0 w1 w2} (ζ01 : w0 ⊒⁻ w1) (ζ12 : w1 ⊒⁻ w2) :
      triangular (trans ζ01 ζ12) =
        trans (triangular ζ01) (triangular ζ12).
    Proof.
      induction ζ01; cbn.
      - now rewrite trans_refl_l.
      - now rewrite trans_assoc, IHζ01.
    Qed.

    Lemma persist_triangular {w0 w1} (t : Ty w0) (r : Tri w0 w1) :
      persist _ t _ (triangular r) = persist _ t _ r.
    Proof. Admitted.

  End Triangular.

  Definition geq {w0 w1} (ζ1 : w0 ⊒ˢ w1) [w2] (ζ2 : w0 ⊒ˢ w2) : Prop :=
    exists ζ12 : w1 ⊒ˢ w2, ζ2 = ζ1 ⊙ ζ12.
  Notation "ζ1 ≽ ζ2" := (geq ζ1 ζ2) (at level 80).

  Lemma geq_refl {w1 w2} (ζ : w1 ⊒ˢ w2) : ζ ≽ ζ.
  Proof. exists refl. symmetry. apply trans_refl_r. Qed.

  Lemma geq_trans {w0 w1 w2 w3} (ζ1 : w0 ⊒ˢ w1) (ζ2 : w0 ⊒ˢ w2) (ζ3 : w0 ⊒ˢ w3) :
    ζ1 ≽ ζ2 -> ζ2 ≽ ζ3 -> ζ1 ≽ ζ3.
  Proof.
    intros [ζ12 H12] [ζ23 H23]. rewrite H23, H12.
    exists (ζ12 ⊙ ζ23). apply trans_assoc.
  Qed.

  Lemma geq_precom {w0 w1 w2 w3} (ζ1 : w0 ⊒ˢ w1) (ζ2 : w1 ⊒ˢ w2) (ζ3 : w1 ⊒ˢ w3) :
    ζ2 ≽ ζ3 -> ζ1 ⊙ ζ2 ≽ ζ1 ⊙ ζ3.
  Proof. intros [ζ23 ->]. exists ζ23. symmetry. apply trans_assoc. Qed.

  Lemma geq_max {w1 w2} (ζ : w1 ⊒ˢ w2) : refl ≽ ζ.
  Proof. exists ζ. symmetry. apply trans_refl_l. Qed.

  Lemma geq_extend {w0 w1 w2} (ζ1 : w0 ⊒ˢ w1) (ζ2 : w1 ⊒ˢ w2) : ζ1 ≽ ζ1 ⊙ ζ2.
  Proof. now exists ζ2. Qed.

  Fixpoint geqb {w0 w1} (ζ1 : w0 ⊒⁻ w1) [w2] (ζ2 : w0 ⊒ˢ w2) {struct ζ1} : bool :=
    match ζ1 with
    | Tri.refl => true
    | Tri.cons x t ζ1 =>
        let ζ2' := thin _ ⊙ ζ2 in
        if Ty_eqdec (subst (Ty_hole _) ζ2) (subst t ζ2')
        then geqb ζ1 ζ2'
        else false
    end.
  Infix "≽?" := geqb (at level 80).

  Lemma geqb_spec {w0 w1} (ζ1 : w0 ⊒⁻ w1) :
    forall [w2] (ζ2 : w0 ⊒ˢ w2),
      Bool.reflect (triangular ζ1 ≽ ζ2) (ζ1 ≽? ζ2).
  Proof.
    induction ζ1; cbn [geqb triangular]; intros w2 ζ2.
    - constructor. apply geq_max.
    - unfold trans at 1. cbn - [Ty_eqdec]. destruct Ty_eqdec.
      + destruct (IHζ1 _ (thin xIn ⊙ ζ2)); constructor; clear IHζ1.
        * destruct g as [ζ2']. exists ζ2'.
          rewrite trans_assoc. rewrite <- H. clear - e.
          apply env.lookup_extensional. intros y yIn. foldlk.
          rewrite lk_trans.
          rewrite lk_thick. unfold thickIn.
          destruct (ctx.occurs_check_view xIn yIn). apply e.
          cbn. now rewrite lk_trans, lk_thin.
        * intros [ζ2' ->]. apply n. clear n. exists ζ2'.
          rewrite <- ?trans_assoc.
          rewrite comp_thin_thick.
          rewrite trans_refl_l.
          reflexivity.
      + constructor. intros [ζ2' ->]. apply n. clear n.
        rewrite <- ?trans_assoc.
        rewrite comp_thin_thick.
        rewrite trans_refl_l.
        cbn. rewrite ?lk_trans, lk_thick.
        unfold thickIn. rewrite ctx.occurs_check_view_refl.
        now rewrite persist_trans.
  Qed.

  Lemma inst_thin {w} (ι : Assignment w) {x} (xIn : x ∈ w) :
    inst (Sub.thin xIn) ι = env.remove x ι xIn.
  Proof.
    rewrite env.remove_remove'.
    apply env.lookup_extensional. intros y yIn.
    unfold env.remove', thin, inst, InstSub.
    now rewrite env.lookup_map, ?env.lookup_tabulate.
  Qed.

  #[export] Instance inst_thick_sub : InstThick Sub.
  Proof.
    intros w x xIn s ι. apply env.lookup_extensional. intros y yIn.
    rewrite env.insert_insert'.
    unfold inst at 1, InstSub, thick, thick_sub, env.insert'.
    rewrite env.lookup_map, !env.lookup_tabulate.
    unfold thickIn. now destruct ctx.occurs_check_view.
  Qed.

  Lemma Ty_subterm_subst {w1 w2} (s t : Ty w1) (ζ : Sub w1 w2) :
    Ty_subterm s t -> Ty_subterm (persist _ s _ ζ) (persist _ t _ ζ).
  Proof.
    unfold Ty_subterm. induction 1; cbn.
    - constructor 1; destruct H; constructor.
    - econstructor 2; eauto.
  Qed.

End Sub.
Export Sub (Sub).
Infix "⊒ˢ" := Sub.Sub.
Infix "≽ˢ" := Sub.geq (at level 80).
(* Infix "≽?" := Sub.geqb (at level 80). *)

(* Infix "≽⁻" := Tri.geq (at level 80). *)
(* Infix "≽?" := Sub.geqb (at level 80). *)

