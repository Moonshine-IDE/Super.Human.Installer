// from the HCL documentation, a simple example servlet:
// https://help.hcltechsw.com/dom_designer/12.0.0/basic/H_EXAMPLE_JAVA_SERVLET_EX.html

import java.util.*;
import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;

public class ExampleServlet extends HttpServlet {
     public void doGet (HttpServletRequest request, HttpServletResponse response) throws IOException {
          response.setContentType("text/html");
          ServletOutputStream out = response.getOutputStream();

          out.println("<HTML><B>Headers sent with the request:</B><BR>");

          for (Enumeration headers = request.getHeaderNames();
                                     headers.hasMoreElements(); ) {
               String headerName = (String) headers.nextElement();
               out.println( "<BR>" + headerName + ": " +
                           request.getHeader(headerName)
               ); // end of out.println

		  } // end of for loop

		  ServletConfig   servlet_config = this.getServletConfig();
		  ServletContext servlet_context = servlet_config.getServletContext();

		  String server_info_str = servlet_context.getServerInfo();
		  out.println( "<BR>" + "Server info: " + server_info_str);

		  //int major_version_int = servlet_context.getMajorVersion();
		  //int major_version_int = servlet_context.getEffectiveMajorVersion();

		  //System.out.println( "Major version: " + major_version_int);


            String java_dir = new File(".").getCanonicalPath();

            //String hostname = java.net.URLEncoder.encode(session.getServerName(), "ISO-8859-1");
            out.println( "<BR>" + "JavaDir" + java_dir);
            out.println( "<BR>" + "JavaVersion" + System.getProperty( "java.version"));
            out.println( "<BR>" + "JavaSpecVer" + System.getProperty("java.specification.version"));
            out.println( "<BR>" + "JavaClassPath" + System.getProperty ("java.class.path"));
            long kb_divisor = 1024 ;
            out.println( "<BR>" + "JavaFreeMem" + Runtime.getRuntime().freeMemory() / kb_divisor + " KB");
            out.println( "<BR>" + "JavaTotalMem" + Runtime.getRuntime().totalMemory() / kb_divisor + " KB");
            //out.println( "<BR>" + "HTTPJVMMaxHeapSize" + session.getEnvironmentString( "HTTPJVMMaxHeapSize", true));



// Server Version: <%= application.getServerInfo() %><br>
//Servlet Version: <%= application.getMajorVersion() %>.<%= application.getMinorVersion() %>
//JSP Version: <%= JspFactory.getDefaultFactory().getEngineInfo().getSpecificationVersion() %> <br>

     } // end of method
} // end of class