let concat ?(sep="\n") = function
  | [] -> Cow.Html.nil
  | [h] -> h
  | h :: hs -> List.fold_left (fun l r -> <:html<$l$$str:sep$$r$>>) h hs

let string_of_html = Cow.Html.to_string

let html_of_string = Cow.Html.of_string ~enc:`UTF_8

let code ?cls data =
  match cls with
    None -> <:html<<code>$data$</code>&>>
  | Some css -> <:html<<code class="$str:css$">$data$</code>&>>

let pre data =
  <:html<<pre>$data$</pre>&>>
