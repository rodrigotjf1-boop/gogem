/// Corpo de exemplo do GET /catalogo/publicado (espelha o snapshot da API).
const publicadoFixture = <String, dynamic>{
  'versao': 3,
  'snapshot': {
    'categorias': [
      {'id': 'cat1', 'nome': 'Burgers'},
      {'id': 'cat2', 'nome': 'Bebidas'},
    ],
    'produtos': [
      {
        'id': 'p1',
        'categoriaId': 'cat1',
        'nome': 'Mister Burguer',
        'descricao': 'Pão, carne 160g, queijo',
        'precoCentavos': 2990,
        'disponivel': true,
        'externalRefs': [
          {'sistema': 'regem', 'codigo_pdv': '101'}
        ],
        'grupos': [
          {
            'id': 'g1',
            'nome': 'Adicionais',
            'min': 0,
            'max': 3,
            'obrigatorio': false,
            'opcoes': [
              {
                'id': 'o1',
                'nome': 'Bacon',
                'precoCentavosDelta': 400,
                'externalRefs': [
                  {'sistema': 'regem', 'codigo_pdv': '201'}
                ]
              }
            ]
          }
        ]
      },
      {
        'id': 'p2',
        'categoriaId': 'cat2',
        'nome': 'Refri Lata',
        'descricao': '',
        'precoCentavos': 700,
        'disponivel': true,
        'externalRefs': [
          {'sistema': 'regem', 'codigo_pdv': '301'}
        ],
        'grupos': []
      },
      {
        'id': 'p3',
        'categoriaId': 'cat1',
        'nome': 'Esgotado Burger',
        'precoCentavos': 1990,
        'disponivel': false,
        'externalRefs': [],
        'grupos': []
      }
    ]
  }
};
