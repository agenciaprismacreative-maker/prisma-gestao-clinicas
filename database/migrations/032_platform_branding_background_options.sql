-- 032: mais opcoes de personalizacao pra tela de login.
--
-- Ate aqui so dava pra escolher imagem de fundo (ou nada, caindo no
-- gradiente fixo do CSS). Agora da pra escolher cor solida ou gradiente
-- customizado tambem, e o cartao de login pode ser claro ou escuro.
--
-- background_type guarda explicitamente qual dos 3 modos esta ativo --
-- nao da pra inferir isso so de background_url estar preenchido, porque a
-- pessoa pode ter enviado uma imagem antes e trocado de ideia depois sem
-- apagar a URL antiga.

alter table public.platform_branding
  add column background_type text not null default 'gradiente'
    constraint platform_branding_background_type_check
    check (background_type in ('imagem', 'solida', 'gradiente')),
  add column background_color text,
  add column gradient_from text,
  add column gradient_to text,
  add column card_style text not null default 'claro'
    constraint platform_branding_card_style_check
    check (card_style in ('claro', 'escuro'));

-- Valores default do gradiente = as mesmas 2 pontas do gradiente fixo que
-- ja existia no CSS antes dessa personalizacao existir, pra quem nunca
-- mexeu nisso continuar vendo exatamente a mesma tela de sempre.
update public.platform_branding
set gradient_from = '#1F332F', gradient_to = '#3C5C55'
where id = 1 and gradient_from is null;
