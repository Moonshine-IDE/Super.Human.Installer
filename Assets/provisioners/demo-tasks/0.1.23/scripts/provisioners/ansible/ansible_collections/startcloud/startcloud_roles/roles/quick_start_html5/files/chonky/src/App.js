import "./styles.css";
import { setChonkyDefaults } from "chonky";
import { ChonkyIconFA } from "chonky-icon-fontawesome";
import { FullFileBrowser, ChonkyActions } from "chonky";
import { useEffect, useState } from "react";
import data from "./data";
import folderSearch from "./folderSearch";
import handleAction from "./chonkyActionHandler";
import { customActions } from "./chonkyCustomActions";

export default function App() {
  const handleActionWrapper = (data) => {
    handleAction(data, setCurrentFolder);
  };
  console.log("start", data);
  setChonkyDefaults({ iconComponent: ChonkyIconFA });

  const [currentFolder, setCurrentFolder] = useState("0");
  const [files, setFiles] = useState(null);
  const [folderChain, setFolderChain] = useState(null);
  const fileActions = [...customActions, ChonkyActions.DownloadFiles];
  useEffect(() => {
    let folderChainTemp = [];
    let filesTemp = [];

    const [found, filesTemp1, folderChainTemp1] = folderSearch(
      data,
      folderChainTemp,
      currentFolder
    );
    if (found) {
      console.log("found", filesTemp1, folderChainTemp1);
      filesTemp = filesTemp1;
      folderChainTemp = folderChainTemp1;
    }

    console.log("files", filesTemp);
    console.log("folders", folderChainTemp);
    setFolderChain(folderChainTemp);
    setFiles(filesTemp);
  }, [currentFolder]);

  return (
    <div className="App">
      <FullFileBrowser
        files={files}
        folderChain={folderChain}
        defaultFileViewActionId={ChonkyActions.EnableListView.id}
        fileActions={fileActions}
        onFileAction={handleActionWrapper}
        disableDefaultFileActions={true}
      />
    </div>
  );
}
