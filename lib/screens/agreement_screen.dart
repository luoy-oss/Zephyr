import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import 'home_screen.dart';

class AgreementScreen extends ConsumerStatefulWidget {
  const AgreementScreen({super.key});

  @override
  ConsumerState<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends ConsumerState<AgreementScreen> {
  bool _hasRead = false;
  bool _isScrollToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (!_isScrollToBottom) {
        setState(() => _isScrollToBottom = true);
      }
    }
  }

  Future<void> _acceptAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('agreement_accepted', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用协议与免责声明'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zephyr - 自动弹琴工具',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '版本 1.0.0',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 24),

                  _SectionTitle('作者立场'),
                  _SectionContent(
                    '本软件作者（luoy-oss）坚决反对利用本软件进行以下行为：\n\n'
                    '• 任何形式的作弊行为：包括但不限于利用本软件在游戏中获取不正当优势\n'
                    '• 破坏游戏公平性：包括但不限于在多人场景中干扰其他玩家体验\n'
                    '• 违反游戏条款：包括但不限于违反游戏用户协议的行为\n'
                    '• 商业牟利：包括但不限于利用本软件进行任何形式的商业活动\n'
                    '• 侵犯他人权益：包括但不限于利用本软件干扰他人正常使用游戏',
                  ),

                  _SectionTitle('软件性质声明'),
                  _SectionContent(
                    '本软件是一款免费、开源的辅助工具，仅供学习研究和娱乐用途。\n\n'
                    '本软件通过 Android 无障碍服务模拟屏幕点击，其原理与用户手动点击屏幕相同，'
                    '不涉及任何游戏内存修改、数据包篡改或外挂行为。\n\n'
                    '作者不鼓励、不支持、不认可任何违反游戏用户协议的使用行为。',
                  ),

                  _SectionTitle('禁止反编译与重新编译'),
                  _SectionContent(
                    '⚠️ 重要声明：\n\n'
                    '任何对本软件进行反编译、反向工程、反汇编、修改源代码后重新编译、'
                    '重新打包或以其他方式篡改本软件的行为都是严格禁止的。\n\n'
                    '具体禁止行为包括但不限于：\n'
                    '• 反编译本软件的 APK 文件\n'
                    '• 修改本软件源代码后重新编译发布\n'
                    '• 移除或修改本软件的版权声明、许可协议\n'
                    '• 将本软件的代码用于其他项目（需遵守开源协议）\n'
                    '• 以任何形式重新打包或分发修改版本\n\n'
                    '违反上述规定将被视为侵权行为，作者保留追究法律责任的权利。',
                  ),

                  _SectionTitle('使用限制'),
                  _SectionContent(
                    '• 本软件仅供学习研究和合规使用\n'
                    '• 用户应遵守当地法律法规和游戏平台规则\n'
                    '• 用户应自行承担使用本软件产生的一切后果\n'
                    '• 作者不对用户使用本软件进行的任何行为负责\n'
                    '• 用户使用本软件即表示同意承担因使用本软件而可能产生的所有风险',
                  ),

                  _SectionTitle('免责声明'),
                  _SectionContent(
                    '1. 本软件按"现状"提供，不作任何明示或暗示的保证，包括但不限于：\n'
                    '   - 适销性保证\n'
                    '   - 特定用途适用性保证\n'
                    '   - 不侵权保证\n\n'
                    '2. 在任何情况下，作者均不对以下情况承担责任：\n'
                    '   - 因使用或无法使用本软件而导致的任何损失\n'
                    '   - 因使用本软件而导致的游戏账号封禁或其他处罚\n'
                    '   - 因使用本软件而导致的数据丢失或损坏\n'
                    '   - 任何直接、间接、偶然、特殊或后果性的损害\n\n'
                    '3. 用户理解并同意，使用本软件的风险完全由用户自行承担。',
                  ),

                  _SectionTitle('版本适用性'),
                  _SectionContent(
                    '许可覆盖范围：\n\n'
                    '本 README 中的所有条款、使用限制和免责声明，仅适用于本项目最新发布的发行版。'
                    '"最新版"以本项目 GitHub 仓库的 Releases 页面中标记为 Latest 的最新版本为准。\n\n'
                    '旧版本使用禁止：\n\n'
                    '作者明确禁止任何人以任何目的使用、修改、分发本项目的任何历史版本（旧版本）。'
                    '所有历史版本均被视为"已撤回许可"的状态。\n\n'
                    '任何对历史版本的下载、安装、运行或分发行为，均一律被视作未经授权的使用，'
                    '构成对本声明的违反。\n\n'
                    '用户义务：\n\n'
                    '使用本软件，即表示您同意并承诺只使用最新版，并已自行将任何现存旧版本替换为最新版。'
                    '因使用旧版本而产生的一切问题（包括但不限于安全漏洞、功能异常、法律风险），'
                    '作者不承担任何责任，全部由使用者自行承担。',
                  ),

                  _SectionTitle('法律责任'),
                  _SectionContent(
                    '• 用户使用本软件即表示同意本免责声明\n'
                    '• 如不同意本声明，请立即停止使用本软件\n'
                    '• 作者保留随时修改本声明的权利\n'
                    '• 本声明的最终解释权归作者所有\n'
                    '• 本声明受中华人民共和国法律管辖',
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 底部确认区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // 阅读提示
                if (!_isScrollToBottom)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '请阅读完整协议内容后方可同意',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),

                // 同意复选框
                Row(
                  children: [
                    Checkbox(
                      value: _hasRead,
                      onChanged: _isScrollToBottom
                          ? (value) => setState(() => _hasRead = value ?? false)
                          : null,
                      activeColor: AppColors.primary,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isScrollToBottom
                            ? () => setState(() => _hasRead = !_hasRead)
                            : null,
                        child: const Text(
                          '我已阅读并同意《使用协议与免责声明》的全部内容',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 确认按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _hasRead ? _acceptAgreement : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '同意并继续',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _hasRead ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 退出按钮
                TextButton(
                  onPressed: () => SystemNavigator.pop(),
                  child: const Text(
                    '不同意并退出',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  final String content;

  const _SectionContent(this.content);

  @override
  Widget build(BuildContext context) {
    return Text(
      content,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: AppColors.textPrimary,
      ),
    );
  }
}
