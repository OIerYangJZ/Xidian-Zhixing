const downloadedImages = {};

const toImages = (post = {}) => {
  if (Array.isArray(post.images)) return post.images;
  if (Array.isArray(post.imageUrls)) return post.imageUrls;
  return [];
};

// HTTP images need a temporary local file in the mini-program runtime.
// HTTPS and relative storage URLs can be rendered directly and must not be
// dropped while the HTTP cache is being prepared.
const isHttpImage = (url) => /^http:\/\//i.test(String(url || ''));

const downloadImage = (url) => {
  const imageUrl = String(url || '').trim();
  if (!isHttpImage(imageUrl)) return Promise.resolve(imageUrl);
  if (downloadedImages[imageUrl]) return Promise.resolve(downloadedImages[imageUrl]);

  return new Promise((resolve, reject) => {
    wx.downloadFile({
      url: imageUrl,
      success: (res) => {
        const statusCode = Number(res.statusCode || 0);
        if (statusCode >= 200 && statusCode < 300 && res.tempFilePath) {
          downloadedImages[imageUrl] = res.tempFilePath;
          resolve(res.tempFilePath);
          return;
        }
        reject(res);
      },
      fail: reject
    });
  });
};

export const attachDisplayImages = (post = {}) => {
  const images = toImages(post);
  return {
    ...post,
    displayImages: images
      .map((url) => {
        if (!isHttpImage(url)) return url;
        return downloadedImages[url] || '';
      })
      .filter(Boolean)
  };
};

export const hydrateDisplayImages = async (posts = []) => {
  const hydratedByPostId = {};

  for (let postIndex = 0; postIndex < posts.length; postIndex += 1) {
    const post = posts[postIndex];
    const images = toImages(post);
    if (!images.some(isHttpImage)) continue;

    const displayImages = await Promise.all(images.map((imageUrl) => downloadImage(imageUrl)));

    hydratedByPostId[String(post.id || '')] = displayImages;
  }

  return hydratedByPostId;
};

export const applyHydratedDisplayImages = (posts = [], hydratedByPostId = {}) => {
  let changed = false;
  const nextPosts = posts.map((post) => {
    const postId = String(post.id || '');
    const displayImages = hydratedByPostId[postId];
    if (!displayImages) return post;
    changed = true;
    return {
      ...post,
      displayImages
    };
  });
  return changed ? nextPosts : posts;
};
