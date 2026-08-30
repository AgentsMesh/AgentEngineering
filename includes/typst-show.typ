#show: book.with(
$if(title)$title: [$title$],$endif$
$if(subtitle)$subtitle: [$subtitle$],$endif$
$if(author)$author: [$for(author)$$author$$sep$, $endfor$],$endif$
)
