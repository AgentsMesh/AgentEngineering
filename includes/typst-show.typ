#show: book.with(
$if(title)$title: [$title$],$endif$
$if(subtitle)$subtitle: [$subtitle$],$endif$
$if(by-author)$author: [$for(by-author)$$by-author.name.literal$$if(by-author.email)$ · $by-author.email$$endif$$sep$, $endfor$],$endif$
)
