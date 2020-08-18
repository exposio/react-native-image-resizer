import { NativeModules, Platform } from 'react-native';


let exportObject = {};

if (Platform.OS === 'android') {
  const ImageResizerAndroid = NativeModules.ImageResizerAndroid;

  exportObject = {
    createResizedImage: (
      imagePath,
      newWidth,
      newHeight,
      compressFormat,
      quality,
      rotation = 0,
      outputPath,
      fileName,
      keepMeta = false
    ) => {
      return new Promise((resolve, reject) => {
        ImageResizerAndroid.createResizedImage(
          imagePath,
          newWidth,
          newHeight,
          compressFormat,
          quality,
          rotation,
          outputPath,
          fileName,
          keepMeta,
          resolve,
          reject
        );
      });
    },
    copyExif: (
      imageSrc,
      imageDest
      ) => {
      return new Promise((resolve, reject) => {
        ImageResizerAndroid.copyExif(
          imageSrc,
          imageDest,
          resolve,
          reject
        );
      });
    },
  };
} else {
  exportObject = {
    createResizedImage: (path, width, height, format, quality, rotation = 0, outputPath, fileName, keepMeta = false) => {
      if (format !== 'JPEG' && format !== 'PNG') {
        throw new Error('Only JPEG and PNG format are supported by createResizedImage');
      }

      return new Promise((resolve, reject) => {
        NativeModules.ImageResizer.createResizedImage(
          path,
          width,
          height,
          format,
          quality,
          rotation,
          outputPath,
          fileName,
          keepMeta,
          (err, response) => {
            if (err) {
              return reject(err);
            }

            resolve(response);
          }
        );
      });
    },
    copyExif: (
      imageSrc,
      imageDest
      ) => {
      return new Promise((resolve, reject) => {
        NativeModules.ImageResizer.copyExif(
          imageSrc,
          imageDest,
          (err, response) => {
            if (err) {
              return reject(err);
            }

            resolve(response);
          }
        );
      });
    },
  };
}

export default exportObject;
