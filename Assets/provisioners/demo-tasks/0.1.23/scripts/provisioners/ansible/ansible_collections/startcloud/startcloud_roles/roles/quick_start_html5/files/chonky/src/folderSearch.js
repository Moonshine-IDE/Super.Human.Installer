const folderSearch = (data1, folderChainTemp, currentFolder) => {
    console.log("search", data1, folderChainTemp, currentFolder);
  
    let filesTemp = [];
    for (let i = 0; i < data1.length; i++) {
      const folder = data1[i];
      folderChainTemp = [
        ...folderChainTemp,
        { id: folder.id, name: folder.name }
      ];
      console.log("id", folder.id, currentFolder);
      if (folder.id === currentFolder) {
        console.log("inside");
        if (folder?.files) {
          folder.files.forEach((file) => {
            filesTemp = [
              ...filesTemp,
              { id: file.id, name: file.name, isDir: file.isDir ? true : false }
            ];
          });
        }
        console.log([true, filesTemp, folderChainTemp]);
        return [true, filesTemp, folderChainTemp];
      } else if (folder?.files) {
        let returnValues = folderSearch(
          folder.files,
          folderChainTemp,
          currentFolder
        );
        console.log("found", returnValues);
        if (returnValues[0]) {
          return returnValues;
        }
      }
      folderChainTemp = folderChainTemp.slice(0, folderChainTemp.length - 1);
    }
    return [0, null, null];
  };
  
  export const findFile = (data, fileId) => {
    console.log("filesearch", data);
    for (let i = 0; i < data.length; i++) {
      const folder = data[i];
      if (folder.id === fileId) {
        return folder;
      } else if (folder?.files) {
        let returnValues = findFile(folder.files, fileId);
        if (returnValues) {
          return returnValues;
        }
      }
    }
    return null;
  };
  
  export default folderSearch;
  