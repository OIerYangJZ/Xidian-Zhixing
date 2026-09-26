export const isValidFileType = (fileType: string) => {
  const validTypes = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'mp4', 'quicktime', 'x-msvideo'];
  return validTypes.includes(fileType.split('/')[1]);
};
