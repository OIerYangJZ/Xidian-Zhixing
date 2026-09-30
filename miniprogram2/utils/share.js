// open-type="share" forwards the tapped component button to its page.
export function sharePost(event) {
  if (event && event.from === 'button') {
    const { postId, title } = event.target.dataset;
    return {
      title: String(title).slice(0, 80),
      path: '/pages/campus/post-detail/index?id=' + encodeURIComponent(postId)
    };
  }
  return { title: '西电知行', path: '/pages/treehole/index' };
}
