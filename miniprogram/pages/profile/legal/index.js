import { applyThemeAndLanguage } from '../../../utils/theme_i18n';
const CONTENT = {
  'user-agreement': {
    title: '用户协议',
    sections: [
      {
        heading: '账号与使用',
        body: '你需要通过西电官方统一身份认证页面完成身份验证。首次认证成功后平台会自动创建账号；账号登录时，学号和密码仅在官方页面输入，西电知行不会接收或保存该登录密码。'
      },
      {
        heading: '内容发布',
        body: '你应对自己发布的帖子、评论、图片和反馈负责。请勿发布违法违规、骚扰攻击、广告引流、侵犯隐私或破坏社区秩序的内容。'
      },
      {
        heading: '平台处理',
        body: '平台会根据社区规范处理违规内容，包括隐藏、删除、限制互动、封禁账号和配合必要的合规处置。'
      }
    ]
  },
  'privacy-policy': {
    title: '隐私政策',
    sections: [
      {
        heading: '收集范围',
        body: '平台会收集学号、统一认证返回的校园身份信息、昵称、头像、发布内容、互动记录、举报记录和必要的设备请求信息。账号登录凭据仅在西电官方页面输入，平台不接收、不保存该登录密码。仅当你主动使用校园服务中心的独立连接功能时，相关凭据才会按对应页面说明处理，且不用于本站账号登录。'
      },
      {
        heading: '匿名展示',
        body: '匿名内容在前台隐藏真实账号信息，但服务端仍保存必要映射，用于举报处理、风控审核和合规追责。'
      },
      {
        heading: '隐私控制',
        body: '你可以在设置中调整陌生人私信和联系入口展示，也可以提交账号注销申请。'
      }
    ]
  },
  'community-guidelines': {
    title: '社区规范',
    sections: [
      {
        heading: '表达边界',
        body: '欢迎真实、友善、理性的校园讨论。禁止人身攻击、恶意造谣、歧视辱骂、泄露隐私、低俗色情、诈骗广告和其他违法违规内容。'
      },
      {
        heading: '申诉与修正',
        body: '如果你认为处理结果有误，可以通过反馈或申诉渠道说明情况，平台会重新核查。'
      }
    ]
  },
  'report-guidelines': {
    title: '举报说明',
    sections: [
      {
        heading: '举报处理',
        body: '你可以对帖子或评论提交举报，管理员会结合内容、上下文和历史记录处理，并通过通知中心反馈结果。'
      },
      {
        heading: '处理结果',
        body: '举报成立时，平台会隐藏或删除违规内容；举报不成立时，原内容保持展示。处理结果会通过通知中心反馈。'
      }
    ]
  },
  acknowledgements: {
    title: '致谢',
    sections: [
      {
        heading: '感谢',
        body: '感谢每一位参与内容建设、反馈问题和维护社区秩序的同学。'
      }
    ]
  }
};

Page({
  onShow() {
    applyThemeAndLanguage(this);
  },
  data: {
    title: '',
    sections: []
  },

  onLoad(options) {
    const type = options.type || 'user-agreement';
    const item = CONTENT[type] || CONTENT['user-agreement'];
    wx.setNavigationBarTitle({ title: item.title });
    this.setData(item);
  }
});
