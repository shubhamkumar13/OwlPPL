open Ppl
open Core

type point_t  = float * float
type param  = float * float

let linreg_model i () = 
  (* observe exactly y=2x+0 *)
  (* let obs = List.init 10 ~f:(fun x -> let x = float_of_int x in (x,x*.2.)) in *)
  (* let linreg' = 
     let open Float in
     let* m = normal 0. 2. in
     let* c = normal 0. 2. in
     List.fold obs ~init:(return (m,c)) ~f:(fun d (x,y) -> observe y (Primitive.(normal (m*x+c) 1.)) d) *)
  let linreg' = 
    let linear = 
      let* a = normal 0. 2. in
      let* b = normal 0. 2. in
      return (a,b)
    in
    let open Float in
    let point d (x,y) = condition' (fun (a,b) -> Primitive.(pdf @@ normal (a*x+b) 1.) y) d in

    let points ps d = List.fold ~f:(point) ~init:d ps in

    let obs = List.init 10 ~f:(fun x -> let x = float_of_int x in (x,x*.2.)) in

    let posterior = points obs linear in
    posterior

  in
  let m = fmap fst linreg' in

  let d = infer m i in
  (* let mn = sample_mean ~n:1000 d in
     Array.iter ~f:(printf "%f, ") (take_k_samples 1000 d);
     printf "%f" mn;mn *)
  sample_mean ~n:1000 d