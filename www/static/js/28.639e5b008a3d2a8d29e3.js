webpackJsonp([28],{"KB/d":function(s,t){},LJch:function(s,t){},PkfQ:function(s,t,i){"use strict";var e={name:"subtitle",props:{name:{type:String,default:""}}},a={render:function(){var s=this.$createElement,t=this._self._c||s;return t("div",{staticClass:"sub_title"},[t("span"),this._v(" "),t("h4",[this._v(this._s(this.name))])])},staticRenderFns:[]};var r=i("VU/8")(e,a,!1,function(s){i("KB/d")},"data-v-0608f019",null);t.a=r.exports},"u/6M":function(s,t,i){"use strict";Object.defineProperty(t,"__esModule",{value:!0});var e=i("PkfQ"),a={name:"wifi_complete",data:function(){return{djsTime:69}},props:{types:{type:Number,default:1},resultData:{type:Object,default:{}},adminPassword:{type:String,default:""},wireless:{type:Boolean,default:!1}},components:{Subtitle:e.a},created:function(){2!=this.types&&(this.adminPassword=this.GLOBAL.adminPassword,this.$route.query&&(this.resultData=this.$route.query))},mounted:function(){var s=this,t=setInterval(function(){s.djsTime=--s.djsTime,0==s.djsTime&&clearInterval(t)},1e3)}},r={render:function(){var s=this,t=s.$createElement,i=s._self._c||t;return i("div",{staticClass:"container complete"},[i("div",{staticClass:"header",class:{headerhas5g:!s.resultData.ssid5g_ssid},attrs:{id:"header"}},[i("div",{staticClass:"iconfont icon-duigou",attrs:{id:"title"}}),s._v(" "),s.resultData.bw160>0?i("div",[i("p",[s._v("配置完成，Wi-Fi重启中")]),s._v(" "),i("p",[s._v("遵照国家法律法规，5G Wi-Fi使用160MHz频宽时，需要做退避雷达信号探测。正在探测，5G Wi-Fi信号要"),i("span",[s._v(s._s(s.djsTime))]),s._v("s后才能开启，请稍候…")])]):i("div",[i("p",[s._v("配置完成，Wi-Fi重启中")]),s._v(" "),i("p",[s._v("再次连接Wi-Fi即可访问互联网")]),s._v(" "),s.wireless?i("p",{staticClass:"fail"},[s._v("若搜不到以下新Wi-Fi，则表示中继连接失败，请重新配置")]):s._e()])]),s._v(" "),i("div",{ref:"con",staticClass:"form  width100",class:{formhas5G:!s.resultData.ssid5g_ssid},attrs:{id:"content"}},[i("Subtitle",{attrs:{name:"您的Wi-Fi密码如下，建议截图保存"}}),s._v(" "),i("div",{staticClass:"wifi_item"},[s._m(0),s._v(" "),i("h3",[s._v(s._s(s.resultData.ssid2g_ssid))]),s._v(" "),i("p",[s._v("Wi-Fi密码")]),s._v(" "),i("h3",[s._v(s._s(s.resultData.ssid2g_passwd))])]),s._v(" "),s.resultData.ssid5g_ssid?i("div",{staticClass:"wifi_item wifi_item2"},[s._m(1),s._v(" "),i("h3",[s._v(s._s(s.resultData.ssid5g_ssid))]),s._v(" "),i("p",[s._v("Wi-Fi密码")]),s._v(" "),i("h3",[s._v(s._s(s.resultData.ssid5g_passwd))])]):s._e(),s._v(" "),i("div",{staticClass:"wifi_item3"},[i("p",{directives:[{name:"show",rawName:"v-show",value:!s.wireless,expression:"!wireless"}]},[s._v("管理后台：  "+s._s(s.resultData.lan_ip))]),s._v(" "),i("p",[s._v("管理密码：  "+s._s(s.adminPassword))]),s._v(" "),i("p",{directives:[{name:"show",rawName:"v-show",value:s.wireless,expression:"wireless"}]},[s._v("推荐安装小米WiFi APP,随时随地管理您的路由")])])],1)])},staticRenderFns:[function(){var s=this.$createElement,t=this._self._c||s;return t("p",[t("span",[this._v("2.4G")]),this._v("  Wi-Fi")])},function(){var s=this.$createElement,t=this._self._c||s;return t("p",[t("span",[this._v("5G")]),this._v("  Wi-Fi")])}]};var n=i("VU/8")(a,r,!1,function(s){i("LJch")},"data-v-eb97ad12",null);t.default=n.exports}});