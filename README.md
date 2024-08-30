# **daikumi_editor**  
这是一个takumi的饭制制谱器 使用love2d引擎制作 程序 ui均由qwws制作  
##**文件创建与应用程序打开**  
    将dakumi_editor打开然后导入带有谱面的zip或是一个音频文件
    love2d相关信息请阅览[love](https://love2d.org/)  
##**注意事项**  
    - 在使用前请切换英文输入法  
    offset的单位为ms  
    bpm的beat分为三个数值 第一个是beat的整数数值 第二个是分数的分母 第三个是分数的分子  
    x w的范围为0-100  
    谱面会保存到love2d的文件夹内 点击按钮open_chart_list能打开
##**一些没那么容易发现的基础操作**   
  类型  操作 操作所对应的结果  
  note  
        q按下 放置一个note  
        w按下 放置一个wipe  
        e按下 放置一个hold头  
        e再次放下  放置一个hold  
        d按下 删除note  
  event  
        在第二个轨道按下e 放置一个x事件的头  
        z再次次在第二个轨道按下e 放置一个x事件  
        在第三个轨道按下e 放置一个w事件的头  
        再次次在第三个轨道按下e 放置一个w事件  
        d 删除所在轨道的事件  
  轨道  
        按下左方向键 将现在所在轨道减1  
        按下右方向键 将现在所在轨道加1  
  分度  
        按下上方向键 将现在所用分度加1  
        按下下方向键 将现在所在分度减1  
演示模式  
        按下tab     进入演示模式  
        再次按下tab 退出演示模式  
点击演示区域  
        点击演示区域轨道 将现在轨道切换到演示区域  
框选  
       拖动鼠标 并且拖动完成时在松开鼠标前按下shift 如果在演示区域  
                                                 框选所有轨道中被框选到的note与事件  
                                                 如果在右侧编辑区域 框选被框选到的事件和note  
需要配合ctrl的事件（以下事件的触发前提都为框选完毕并且按住了ctrl）  
       按下c    复制框选的内容  
       按下x    裁剪框选的内容  
       按下v    粘贴框选的内容 如果在演示区域 只粘贴note  
       按下b    粘贴note和反向粘贴框选的事件  
       按下a＋v并且框选内容在演示区域 粘贴note和粘贴框选的事件  
       按下a＋b并且框选内容在演示区域 粘贴note和反向粘贴框选的事件  
       按下z    撤回上一步对note的操作
       按下y    重做上一步对note的操作  
  ##**相关**  
  [LxgwNeoXiHei](https://github.com/lxgw/LxgwNeoXiHei)  
  [love2d](https://github.com/love2d/love)  
  [dkjson](https://github.com/LuaDist/dkjson)  
  [nativefs](https://github.com/zorggn/nativefs)  
  [7zip](https://github.com/ip7z/7zip)
  
