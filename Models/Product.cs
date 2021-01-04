using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Net;

namespace dvcsharp_core_api.Models
{
   public class Product
   {
      public int ID { get; set; }

      [StringLength(60)]
      [Required]
      public string name { get; set; }

      [Required]
      public string description { get; set; }

      [Required]
      public string skuId { get; set; }

      [Required]
      [Range(1, int.MaxValue, ErrorMessage = "Please enter a value greater than {1}")]
      public int unitPrice { get; set; }

      public string imageUrl;
      public string category;
      [NotMapped]
      public dynamic obj { get; set; }

      /// <summary>
      /// This method will check a url to see that it does not return server or protocol errors
      /// </summary>
      /// <param name="url">The path to check</param>
      /// <returns></returns>
      public bool imageExists()
      {
         try
         {
            HttpWebRequest request = HttpWebRequest.Create(imageUrl) as HttpWebRequest;
            request.Timeout = 5000; //set the timeout to 5 seconds to keep the user from waiting too long for the page to load
            request.Method = "HEAD"; //Get only the header information -- no need to download any content

            using (HttpWebResponse response = request.GetResponse() as HttpWebResponse)
            {
                  int statusCode = (int)response.StatusCode;
                  if (statusCode >= 100 && statusCode < 400) //Good requests
                  {
                     return true;
                  }
                  else if (statusCode >= 500 && statusCode <= 510) //Server Errors
                  {
                     //log.Warn(String.Format("The remote server has thrown an internal error. Url is not valid: {0}", url));
                     Console.WriteLine(String.Format("The remote server has thrown an internal error. Url is not valid: {0}", imageUrl));
                     return false;
                  }
            }
         }
         catch (WebException ex)
         {
            if (ex.Status == WebExceptionStatus.ProtocolError) //400 errors
            {
                  return false;
            }
            else
            {
                  Console.WriteLine(String.Format("Unhandled status [{0}] returned for url: {1}", ex.Status, imageUrl), ex);
            }
         }
         catch (Exception ex)
         {
            Console.WriteLine(String.Format("Could not test url {0}.", imageUrl), ex);
         }
         return false;
      }
   }
}