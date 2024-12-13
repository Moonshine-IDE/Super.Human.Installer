const data = [
    {
      id: "0",
      name: "Root",
      isDir: true,
      files: [
        {
          id: "1",
          name: "Administration",
          isDir: true,
          files: [
            {
              id: "11",
              name: "Performance",
              isDir: true,
              files: [
                {
                  id: "111",
                  name: "Quaterly Reports",
                  isDir: true,
                  files: [
                    {
                      id: "1111",
                      name: "2020-qty-report1.pdf"
                    },
                    {
                      id: "1112",
                      name: "2020-qty-report2.pdf"
                    }
                  ]
                }
              ]
            }
          ]
        },
        { id: "2", name: "Closure", isDir: true },
        { id: "3", name: "Formation", isDir: true }
      ]
    }
  ];
  export default data;
  