import { ChonkyActions } from "chonky";
import { findFile } from "./folderSearch";
import fileData from "./data";

const handleAction = (data, setCurrentFolder) => {
  console.log("handle", data);
  if (data.id === ChonkyActions.OpenFiles.id) {
    const file = findFile(fileData, data.payload.files[0].id);
    if (file?.isDir) {
      console.log("fileid", file.id);
      setCurrentFolder(file.id);
    }
  }
};

export default handleAction;
