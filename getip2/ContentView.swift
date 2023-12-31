//
//  ContentView2.swift
//  getip2
//
//  Created by 汤鹏 on 9/5/23.
//

import SwiftUI
import Kanna
import HTTPTaskPublisher
import Alamofire
import SwiftSoup
import Stream

struct ContentView: View {
    
    @State var isSync = false;
    @State var hostFile = "#git ip";
    @State var ipaddress = "https://sites.ipaddress.com/";
    var window = NSScreen.main?.visibleFrame
    @State var domains = [
        "github.githubassets.com",
        "central.github.com",
        "desktop.githubusercontent.com",
        "assets-cdn.github.com",
        "camo.githubusercontent.com",
        "github.map.fastly.net",
        "github.global.ssl.fastly.net",
        "gist.github.com",
        "github.io",
        "github.com",
        "api.github.com",
        "raw.githubusercontent.com",
        "user-images.githubusercontent.com",
        "favicons.githubusercontent.com",
        "avatars5.githubusercontent.com",
        "avatars4.githubusercontent.com",
        "avatars3.githubusercontent.com",
        "avatars2.githubusercontent.com",
        "avatars1.githubusercontent.com",
        "avatars0.githubusercontent.com",
        "avatars.githubusercontent.com",
        "codeload.github.com",
        "github-cloud.s3.amazonaws.com",
        "github-com.s3.amazonaws.com",
        "github-production-release-asset-2e65be.s3.amazonaws.com",
        "github-production-user-asset-6210df.s3.amazonaws.com",
        "github-production-repository-file-5c1aeb.s3.amazonaws.com",
        "githubstatus.com",
        "github.community",
        "media.githubusercontent.com",
        "copilot-proxy.githubusercontent.com",
        "cloud.githubusercontent.com",
        "pipelines.actions.githubusercontent.com",
        "objects.githubusercontent.com",
        "translate.googleapis.com"
    ]
    
    var body: some View {
        
        VStack {
            //同步按钮，自动同步逻辑
            Form {
                Section(){
                    Toggle(isOn: $isSync){
                        Text("同步")
                    }
                    .toggleStyle(SwitchToggleStyle())
                }
            }
            .ignoresSafeArea(edges: .top)
            
            Divider()
            
            //读取本机hosts文件
            HStack{
                //文本框，存host记录
                TextEditor(text: .constant(hostFile))
                
                //手动刷新hosts文件按钮
                Button("手动刷新") {
                    hostFile = "";
                    let logfileURL = URL(fileURLWithPath: "/etc/").appendingPathComponent("hosts")
                    
                    let exist = FileManager.default.fileExists(atPath: "/etc/hosts")
                    // 判断hosts文件是否为空,空的话创建一个
                    if(!exist){
                        FileManager.default.createFile(atPath: logfileURL.path, contents: nil, attributes: nil)
                    }
                    
                    //备份文件
                    var bakName:String = "host-temp-\(String(arc4random())).bak"
                    let existBak = FileManager.default.fileExists(atPath: "/etc/\(bakName)")
                    // 判断hosts文件是否为空,空的话创建一个
                    if(!existBak){
                        let isFile = FileManager.default.createFile(atPath: NSTemporaryDirectory() + "/\(bakName)", contents: nil, attributes: nil)
                    }
                    let fileHandlerBak = try! FileHandle(forWritingTo: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(bakName))
                    
                    var cache:String = "";
                    //按行读取旧的hosts文件，一次性读取到内存再做处理
                    for line:String in try! String(contentsOfFile: logfileURL.path).components(separatedBy: ["\n"]){
                        //添加到备份文件
                        fileHandlerBak.write(line.data(using: .utf8)!)
                        
                        //忽略包含#开头的行
                        if line.hasPrefix("#") {
                            //添加到文本框
                            hostFile.append("\n")
                            hostFile.append(line)
                            cache.append("\n")
                            cache.append(line)
                        }else {
                            //当指定网址存在则不添加进替换文件
                            var isDelete:Bool = true;
                            for domain in domains {
                                if line.contains(domain) {
                                    isDelete = false;
                                }
                            }
                            if isDelete {
                                //添加到文本框
                                hostFile.append("\n")
                                hostFile.append(line)
                                cache.append("\n")
                                cache.append(line)
                            }
                        }
                    }
                    
                    //声明文件管理
                    let fileHandler = try! FileHandle(forWritingTo: logfileURL)
                    print("备份文件地址：\(NSTemporaryDirectory())/\(bakName)")
                    
                    //删除原文件内容
                    do {
                        try fileHandler.truncate(atOffset: 0)
                    }catch {
                        print(error)
                    }
                    fileHandler.seekToEndOfFile()
                    //写入原来的文件
                    fileHandler.write(cache.data(using: .utf8)!)
                    
                    //异步跑获取ip方法并替换内容
                    for domain in domains {
                        getHost(url:domain, file:fileHandler)
                    }
                }
            }.frame(width: window!.width / 2.0, height: window!.height / 1.5)
        }.frame(width: window!.width / 2.0, height: window!.height / 1.5)
    }
    
    //获取网站访问ip
    func getHost(url:String, file:FileHandle) -> Void {
        var html:String = ""
        //请求解析ip网站
        AF.request(ipaddress+url).response { response in
            if response.data == nil {
                return;
            }
            html = String(data: response.data!, encoding: .utf8)!
            do {
                //解析html
                let doc: Document = try SwiftSoup.parse(html)
                if try doc.getElementById("tabpanel-dns-a") == nil {
                    return;
                }
                
                
                //直接搜索ip所在标签的id，可能会变
                var link: Element = try doc.getElementById("tabpanel-dns-a")!
                //ip现在是使用a标签包起来的
                let elements: Elements = try link.getAllElements().select("a")
                
                if elements.first() == nil {
                    return;
                }
                
                //多个ip取第一个
                link = elements.first()!
                let linkText: String = try link.text();
                
                //添加到文本框
                hostFile.append("\n")
                hostFile.append(url+" "+linkText)
                file.write(String("\n").data(using: .utf8)!)
                file.write(String(url+" "+linkText).data(using: .utf8)!)
            } catch Exception.Error(_, let message) {
                print(message)
            } catch {
                print("error")
            }
        }
    }
}
