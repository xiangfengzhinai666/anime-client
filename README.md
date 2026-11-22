# 杩界暘瀹㈡埛绔紙AniCh 褰㈡€佸鍒?路 涓汉鑷敤锛?
Windows 浼樺厛鐨勮拷鐣鎴风锛屽弬鐓?[Sle2p/AniCh](https://github.com/Sle2p/AniCh) 鐨勪骇鍝佸舰鎬?*閲嶆柊瀹炵幇**锛堥潪 fork锛氫笂娓告棤 LICENSE锛屼笖鍏?1.5.x 鐗堟湰涓嶅紑婧愶級銆?
> 褰撳墠鐘舵€侊細**S0 瀹屾垚 鉁?+ 宸插楠?*锛堢幆澧?/ 鑴氭墜鏋?/ 鑷绐楀彛 / 鍝佺墝鍥炬爣锛?> 璇﹁ [docs/S0-REPORT.md](docs/S0-REPORT.md) 涓?[docs/S0-VERIFY.md](docs/S0-VERIFY.md)

![S0 鑷绐楀彛](docs/assets/s0-selfcheck.png)

## 鍝佺墝

鍥炬爣鍙栬嚜鏈湴绱犳潗锛堜釜浜轰娇鐢級锛屼竷妗?ICO 瑕嗙洊 16鈥?56 px锛涙崲鍥句竴鏉″懡浠わ細

```powershell
python scripts/gen_icon.py "D:\pics\fav.jpg" --crop 0.84
flutter build windows --release
```

![鍥炬爣鍚勫昂瀵竇(docs/assets/icon-sizes.png)

## 蹇€熷紑濮?
```powershell
flutter pub get
flutter test                        # 3 涓嚜妫€鐢ㄤ緥
flutter run -d windows              # 寮€鍙戣繍琛?flutter build windows --release     # 浜у嚭 build\windows\x64\runner\Release\anime_client.exe
```

宸ュ叿閾剧増鏈笌璺緞瑙?[docs/TOOLCHAIN.md](docs/TOOLCHAIN.md)锛堝惈浠ｇ悊銆佹埅鍥俱€佸凡鐭ュ潙锛夈€?
## 鐩爣锛圱ier 1锛氳兘鐪嬶級

- 棣栭〉 / 鐣墽绱㈠紩 / 鎼滅储 / 璇︽儏 / 鍓ч泦
- 鎾斁鍣細澶氱嚎璺€侀€夐泦銆佸€嶉€熴€佸叏灞忋€佸揩鎹烽敭銆佺画鎾?- 寮瑰箷锛氳嚜鐮斿紩鎿庯紙杞ㄩ亾 / 纰版挒 / 鎻忚竟锛? 澶氳矾寮瑰箷鏁版嵁 + 鍏抽敭璇嶅睆钄?- 杩界暘锛堟兂鐪?/ 鍦ㄧ湅 / 鐪嬭繃锛夈€佽鐪嬪巻鍙?- 鎵撳寘涓哄彲鍙屽嚮杩愯鐨?exe

## 鎶€鏈€夊瀷

| 灞?| 閫夊瀷 | 璇存槑 |
|---|---|---|
| 妗嗘灦 | Flutter | 涓€濂椾唬鐮侊紝鍚庣画鍙嚭 Android |
| 鎾斁 | media_kit (libmpv) | 纭В / HLS / 鎴浘 / 鍊嶉€?|
| 鐘舵€佺鐞?| Riverpod | 鍙祴銆佷緷璧栨竻鏅?|
| 鏈湴瀛樺偍 | drift (SQLite) | 鍘嗗彶銆佽拷鐣€佽繘搴︺€佸脊骞曠紦瀛?|
| 婧愭帴鍏?| 閫傞厤鍣ㄦ彃浠跺寲 | 鍔犱竴涓簮 = 鍔犱竴涓?adapter锛屼笉鏀逛富娴佺▼ |

## 闃舵鍒掑垎

| 闃舵 | 鍐呭 | 鐘舵€?|
|---|---|---|
| S0 | 鐜锛團lutter SDK / VS Build Tools锛?| 鉁?瀹屾垚 |
| S1 | 楠ㄦ灦锛堜富棰?/ 璺敱 / 瀵艰埅 / 鏈湴搴擄級 | 寰呭紑濮?|
| S2 | 鏁版嵁灞傦紙鍏冩暟鎹?/ 绱㈠紩 / 鎼滅储 / 璇︽儏锛?| 寰呭紑濮?|
| S3 | 鎾斁鍣?+ 绗竴涓簮閫傞厤鍣?| 寰呭紑濮?|
| S4 | 寮瑰箷寮曟搸 + 澶氳矾鏁版嵁 | 寰呭紑濮?|
| S5 | 杩界暘 / 鍘嗗彶 | 寰呭紑濮?|
| S6 | 鎵撳寘锛坋xe / 瀹夎鍣級 | 寰呭紑濮?|
| S7 | 澶氭簮 + 鍥涜矾寮瑰箷锛圱ier 2锛?| 寰呭紑濮?|
| S8 | 瓒呭垎 / 涓嬭浇 / PIP / Android锛圱ier 3锛?| 寰呭紑濮?|

## 绾﹀畾

- 浠撳簱淇濇寔 **private**锛屼笉瀵瑰鍒嗗彂銆?- 涓嶆彁浜や换浣曡处鍙枫€乼oken銆乧ookie锛涚櫥褰曟€佷粎瀛樻湰鏈猴紙Windows DPAPI 鍔犲瘑锛夈€?- 姣忎釜闃舵涓€涓?commit / tag锛屼究浜庡洖婊氥€?
## 鑷磋阿

浜у搧褰㈡€佸弬鑰?[Sle2p/AniCh](https://github.com/Sle2p/AniCh)锛堜粎鍙傝€冭璁★紝鏈娇鐢ㄥ叾浠ｇ爜锛夈€?