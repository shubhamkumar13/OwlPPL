(* open Common *)
open Core
open Dist
open Common

(* likelihood weighting *)
let importance n d = sequence @@ List.init n ~f:(fun _ -> prior d)

let importance' n d =
  let* l = importance n d in
  let l = List.map ~f:(fun (x, y) -> (x, Dist.Prob.to_float y)) l in
  categorical l

(* let importance' n d = 
   let particles_dist = sequence @@ List.init n ~f:(fun _ -> prior d) in
   let* particles = particles_dist in 
   categorical particles *)

let rec create' n d sofar =
  (* printf "create\n"; *)
  if n = 0 then sofar
  else
    match sample d with
    | Some x -> create' (n - 1) d (x :: sofar)
    | None -> create' n d sofar

let create n d = create' n d []

type rejection_type = Hard | Soft [@@deriving show]

let reject_transform_hard ?(threshold = 0.) d =
  let rec repeat () =
    let* x, s = prior_with_score d in
    if Float.(Dist.Prob.to_float s > threshold) then return (x, s)
    else repeat ()
  in
  repeat ()

let rec reject'' : 'a. 'a dist -> 'a option dist = function
  | Conditional (c, d') -> (
      let* x = reject'' d' in
      match x with
      | Some y ->
          if Float.(Dist.Prob.to_float (c y) = 0.) then return None
          else return (Some y)
      | None -> return None )
  | Bind (d, f) -> (
      let* x = reject'' d in
      match x with
      | Some y ->
          let* z = reject'' (f y) in
          return z
      | None -> return None )
  | x ->
      let* y = x in
      return (Some y)

let reject_transform_soft d =
  let rec repeat () =
    let* x, s = prior_with_score d in
    let* accept = bernoulli (Dist.Prob.to_float s) in
    if accept then return (x, s) else repeat ()
  in
  repeat ()

let rejection_transform ?(n = 10000) s d =
  let reject_dist =
    match s with
    | Hard -> reject_transform_hard ~threshold:0.
    | Soft -> reject_transform_soft
  in
  let* l = sequence @@ List.init n ~f:(fun _ -> reject_dist d) in
  let l = List.map ~f:(fun (x, y) -> (x, Dist.Prob.to_float y)) l in
  categorical l

let rejection_soft d =
  let* x, s = prior_with_score d in
  let* accept = bernoulli (Dist.Prob.to_float s) in
  if accept then return (Some (x, s)) else return None

let rejection_hard ?(threshold = 0.) d =
  let* x, s = prior_with_score d in
  if Float.(Dist.Prob.to_float s > threshold) then return (Some (x, s))
  else return None

let rejection ?(n = 10000) s d =
  let reject_dist =
    match s with Hard -> rejection_hard ~threshold:0. | Soft -> rejection_soft
  in
  (* List.init n ~f:(fun _ -> sample (reject_dist d))
     |> List.filter ~f:(is_some)
     |> List.filter_opt *)
  create n (reject_dist d)
  |> unduplicate |> normalise
  |> List.map ~f:(fun (x, y) -> (x, Dist.Prob.to_float y))
  |> categorical

(* 
let rec create d n =
  if n = 0 then [] 
  else 
    match sample d with
    | Some x -> x::(create d (n-1))
    | None -> create d n *)
