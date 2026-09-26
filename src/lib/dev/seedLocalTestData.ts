import 'server-only';
import prisma from '@/lib/prisma/prisma';

const localPeers = [
  { id: 'local-peer-lin-xi', username: 'linxi', name: '林曦', bio: '计算机学院 · 喜欢拍照和记录校园。' },
  { id: 'local-peer-zhou-yu', username: 'zhouyu', name: '周予', bio: '在图书馆和实验室之间切换。' },
  { id: 'local-peer-chen-an', username: 'chenan', name: '陈安', bio: '通信工程 · 慢慢来，也很快。' },
  { id: 'local-peer-song-yue', username: 'songyue', name: '宋月', bio: '校园跑步路线收集者。' },
];

export async function seedLocalTestData(userId: string) {
  const [user, ...peers] = await Promise.all([
    prisma.user.upsert({
      where: { id: userId },
      update: { status: 'ACTIVE' },
      create: { id: userId, username: 'localtest', name: '本地测试同学' },
    }),
    ...localPeers.map((peer) =>
      prisma.user.upsert({
        where: { id: peer.id },
        update: { username: peer.username, name: peer.name, bio: peer.bio, status: 'ACTIVE' },
        create: { ...peer, status: 'ACTIVE' },
      }),
    ),
  ]);

  const followPairs = [
    [user.id, peers[0].id],
    [user.id, peers[1].id],
    [peers[2].id, user.id],
    [peers[3].id, user.id],
  ];
  await Promise.all(
    followPairs.map(([followerId, followingId]) =>
      prisma.follow.upsert({
        where: { followerId_followingId: { followerId, followingId } },
        update: {},
        create: { followerId, followingId },
      }),
    ),
  );

  const now = Date.now();
  const demoPosts = [
    { id: 981001, ownerId: user.id, content: '早八前的校园，风把桂花香送到了教学楼。#西电日常' },
    { id: 981002, ownerId: peers[0].id, content: '今天的中心广场很适合散步，顺手拍下了傍晚的光。#长安校区' },
    { id: 981003, ownerId: peers[1].id, content: '图书馆新发现一个靠窗的位置，下午的光刚刚好。' },
    { id: 981004, ownerId: peers[2].id, content: '实验室项目终于跑通了，给一起熬夜的队友点个赞。' },
    { id: 981005, ownerId: user.id, content: '有人一起去操场夜跑吗？绕湖两圈，慢慢跑就好。#夜跑' },
    { id: 981006, ownerId: peers[3].id, content: '分享一条从宿舍到图书馆的秋日路线，路边银杏开始变黄啦。' },
  ];
  await Promise.all(
    demoPosts.map((post, index) =>
      prisma.post.upsert({
        where: { id: post.id },
        update: { content: post.content, userId: post.ownerId, status: 'PUBLISHED' },
        create: {
          id: post.id,
          userId: post.ownerId,
          content: post.content,
          status: 'PUBLISHED',
          displayIdentity: 'USER',
          createdAt: new Date(now - index * 47 * 60 * 1000),
        },
      }),
    ),
  );

  const likedPost = await prisma.postLike.upsert({
    where: { userId_postId: { userId: peers[0].id, postId: demoPosts[0].id } },
    update: {},
    create: { userId: peers[0].id, postId: demoPosts[0].id },
  });
  await prisma.activity.upsert({
    where: { id: 981001 },
    update: { sourceId: likedPost.id, targetId: demoPosts[0].id },
    create: {
      id: 981001,
      type: 'POST_LIKE',
      sourceId: likedPost.id,
      targetId: demoPosts[0].id,
      sourceUserId: peers[0].id,
      targetUserId: user.id,
    },
  });

  await prisma.comment.upsert({
    where: { id: 981001 },
    update: { content: '这张照片好有秋天的感觉！', userId: peers[1].id, postId: demoPosts[0].id },
    create: { id: 981001, content: '这张照片好有秋天的感觉！', userId: peers[1].id, postId: demoPosts[0].id },
  });
  await prisma.comment.upsert({
    where: { id: 981002 },
    update: { content: '谢谢，今天刚好遇上晚霞。', userId: user.id, postId: demoPosts[0].id, parentId: 981001 },
    create: {
      id: 981002,
      content: '谢谢，今天刚好遇上晚霞。',
      userId: user.id,
      postId: demoPosts[0].id,
      parentId: 981001,
    },
  });

  const conversationId = 'local-test-conversation';
  await prisma.conversation.upsert({ where: { id: conversationId }, update: {}, create: { id: conversationId } });
  await Promise.all(
    [user.id, peers[0].id].map((participantId) =>
      prisma.conversationParticipant.upsert({
        where: { conversationId_userId: { conversationId, userId: participantId } },
        update: {},
        create: { conversationId, userId: participantId },
      }),
    ),
  );
  const messages = [
    { id: 'local-test-message-1', senderId: peers[0].id, content: '周末想去校园里拍照，你有空吗？' },
    { id: 'local-test-message-2', senderId: user.id, content: '有呀！我们可以从图书馆一路走到中心广场。' },
    { id: 'local-test-message-3', senderId: peers[0].id, content: '好，下午四点在图书馆门口见～' },
  ];
  await Promise.all(
    messages.map((message) =>
      prisma.message.upsert({
        where: { id: message.id },
        update: { content: message.content, senderId: message.senderId },
        create: { ...message, conversationId },
      }),
    ),
  );

  const aiConversationId = 'local-test-ai-conversation';
  await prisma.aiConversation.upsert({
    where: { id: aiConversationId },
    update: { title: '规划一周校园生活' },
    create: { id: aiConversationId, userId: user.id, title: '规划一周校园生活' },
  });
  const aiMessages = [
    { id: 'local-test-ai-message-1', role: 'USER' as const, content: '帮我安排一个兼顾课程、运动和复习的一周计划。' },
    {
      id: 'local-test-ai-message-2',
      role: 'ASSISTANT' as const,
      content: '可以先把固定课程放进日历，再为复习留出每天两段专注时间。运动安排在课后，选离教学楼近的时段更容易坚持。',
    },
    { id: 'local-test-ai-message-3', role: 'USER' as const, content: '周三晚上我有社团活动，周五想留给项目讨论。' },
    {
      id: 'local-test-ai-message-4',
      role: 'ASSISTANT' as const,
      content:
        '我会把周三晚上和周五项目讨论固定下来，再将复习分散到周一、周二、周四和周末。这样每天都有明确重点，也留出了调整空间。',
    },
  ];
  await Promise.all(
    aiMessages.map((message) =>
      prisma.aiMessage.upsert({
        where: { id: message.id },
        update: { content: message.content, role: message.role },
        create: { ...message, conversationId: aiConversationId },
      }),
    ),
  );
}
